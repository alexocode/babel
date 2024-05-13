defmodule Babel.Pipeline do
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
  def apply(%__MODULE__{} = pipeline, %Context{} = context) do
    {reversed_traces, result} =
      pipeline.reversed_steps
      |> Enum.reverse()
      |> Enum.reduce_while(
        {[], {:ok, context.current}},
        fn applicable, {traces, {:ok, current}} ->
          trace = Applicable.apply(applicable, %Context{context | current: current})
          traces = [trace | traces]
          result = Trace.result(trace)

          cond do
            Trace.ok?(trace) ->
              {:cont, {traces, result}}

            is_nil(pipeline.on_error) ->
              {:halt, {traces, result}}

            true ->
              on_error_trace = OnError.recover(pipeline.on_error, Error.new(trace))

              {:halt, {[on_error_trace | traces], Trace.result(on_error_trace)}}
          end
        end
      )

    Trace.new(pipeline, context, result, Enum.reverse(reversed_traces))
  end

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
    equal_or_any_nil?(left.name, right.name) and
      equal_or_any_nil?(left.on_error, right.on_error)
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
    defdelegate apply(pipeline, data), to: Babel.Pipeline
  end
end
