defmodule Babel.Pipeline do
  @moduledoc """
  Represents a sequence of `Babel.Step`s (or nested `Babel.Pipeline`s) that get
  evaluated sequentially, when a step fails the pipeline stops and - if set -
  invokes the `on_error` handler in an attempt to recover from the error.

  Pipelines can be chained together (using `chain/2`). Babel will try to simplify
  pipeline chains by merging pipelines without distinct names and no error handling.
  """

  alias __MODULE__.OnError
  alias Babel.Applicable
  alias Babel.Error
  alias Babel.Context
  alias Babel.Trace
  alias Babel.Step

  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(_input, output) :: %__MODULE__{
          name: name,
          on_error: nil | on_error(output),
          reversed_steps: [step]
        }
  defstruct name: nil,
            on_error: nil,
            reversed_steps: []

  @typedoc "A term describing what this pipeline does"
  @type name :: Babel.name()
  @type step :: Applicable.t()
  @type on_error :: on_error(term)
  @type on_error(output) :: (Error.t() -> Step.result_or_trace(output))

  @spec new(step | [step]) :: t
  @spec new(name | nil, step | [step]) :: t
  @spec new(name | nil, on_error | nil, step | [step]) :: t
  def new(name \\ nil, on_error \\ nil, step_or_steps)

  def new(nil, nil, %__MODULE__{} = t), do: t

  def new(name, on_error, %__MODULE__{} = t) do
    chain(build(name, on_error, []), t)
  end

  def new(name, on_error, step_or_steps), do: build(name, on_error, step_or_steps)

  defp build(name, on_error, step_or_steps) do
    %__MODULE__{
      name: name,
      on_error: OnError.new(on_error),
      reversed_steps:
        step_or_steps
        |> List.wrap()
        |> Enum.reverse()
    }
  end

  @spec apply(t(input, output), Context.t(input)) :: Trace.t(output) when input: any, output: any
  def apply(%__MODULE__{} = pipeline, %Context{data: data, history: history}) do
    {reversed_traces, _, result} =
      pipeline.reversed_steps
      |> Enum.reverse()
      |> Enum.reduce_while(
        {[], history, {:ok, data}},
        fn applicable, {traces, history, {:ok, data}} ->
          trace = Applicable.apply(applicable, Context.new(data, history))
          traces = [trace | traces]
          history = [trace | history]
          result = Trace.result(trace)

          cond do
            Trace.ok?(trace) ->
              {:cont, {traces, history, result}}

            is_nil(pipeline.on_error) ->
              {:halt, {traces, history, result}}

            true ->
              on_error_trace = OnError.recover(pipeline.on_error, Error.new(trace))
              traces = [on_error_trace | traces]
              history = [on_error_trace | history]

              {:halt, {traces, history, Trace.result(on_error_trace)}}
          end
        end
      )

    Trace.new(pipeline, data, result, Enum.reverse(reversed_traces))
  end

  @doc """
  Combines a `Babel.Pipeline` either with another `Babel.Pipeline` or a list of
  steps. Passing another `Babel.Pipeline` might lead both pipelines being merged
  into one larger `Babel.Pipeline`.

  ## Merging
  When all of the following conditions match two `Babel.Pipeline`s get merged:

  1. at least one pipeline has no `name` or both `name`s are equal
  2. at least one pipeline has no `on_error` handler

  In all other cases the second `Babel.Pipeline` will be included as a step of
  the first `Babel.Pipeline`.
  """
  @spec chain(t(input, in_between), t(in_between, output)) :: t(input, output)
        when input: any, in_between: any, output: any
  def chain(%__MODULE__{} = left, %__MODULE__{} = right) do
    if merge?(left, right) do
      merge(left, right)
    else
      Map.update!(left, :reversed_steps, &[right | &1])
    end
  end

  @spec chain(t, [step]) :: t
  def chain(%__MODULE__{} = pipeline, steps) when is_list(steps) do
    Map.update!(
      pipeline,
      :reversed_steps,
      &Enum.concat(Enum.reverse(steps), &1)
    )
  end

  @spec chain(t, step) :: t
  def chain(%__MODULE__{} = pipeline, step) do
    Map.update!(
      pipeline,
      :reversed_steps,
      &[step | &1]
    )
  end

  defp merge?(%__MODULE__{} = left, %__MODULE__{} = right) do
    equal_or_any_nil?(left.name, right.name) and (is_nil(left.on_error) or is_nil(right.on_error))
  end

  defp equal_or_any_nil?(left, right) do
    left == right or is_nil(left) or is_nil(right)
  end

  defp merge(%__MODULE__{} = left, %__MODULE__{} = right) do
    %__MODULE__{
      name: left.name || right.name,
      on_error: left.on_error || right.on_error,
      reversed_steps: right.reversed_steps ++ left.reversed_steps
    }
  end

  @spec on_error(t, on_error) :: t
  def on_error(%__MODULE__{} = pipeline, on_error) do
    %__MODULE__{pipeline | on_error: OnError.new(on_error)}
  end

  defimpl Applicable do
    def apply(pipeline, context) do
      Babel.Telemetry.span(
        [:babel, :pipeline],
        %{babel: pipeline, input: context},
        fn ->
          trace_or_result =
            try do
              Babel.Pipeline.apply(pipeline, context)
            rescue
              error in [Babel.Error] -> error.trace
              other -> {:error, other}
            end

          trace =
            case trace_or_result do
              %Babel.Trace{} = trace -> trace
              result -> Babel.Trace.new(pipeline, context, result)
            end

          {trace, %{babel: pipeline, input: context, trace: trace, result: if(Babel.Trace.ok?(trace), do: :ok, else: :error)}}
        end
      )
    end
  end
end
