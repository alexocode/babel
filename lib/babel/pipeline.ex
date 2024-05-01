defmodule Babel.Pipeline do
  alias __MODULE__.OnError
  alias Babel.Error
  alias Babel.Trace

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
  @type name() :: Babel.name()
  @type step() :: Babel.Applicable.t()
  @type on_error :: on_error(term)
  @type on_error(output) :: Babel.Step.fun(Error.t(), output)

  @spec new(step | [step]) :: t
  @spec new(name, step | [step]) :: t
  @spec new(name, on_error, step | [step]) :: t
  def new(name \\ nil, on_error \\ nil, step_or_steps)

  def new(nil, nil, %__MODULE__{} = t), do: t

  def new(name, on_error, %__MODULE__{} = t) do
    case t do
      %{name: ^name, on_error: %OnError{handler: ^on_error}} -> t
      %{name: nil, on_error: %OnError{handler: ^on_error}} -> %{t | name: name}
      %{name: ^name, on_error: nil} -> %{t | on_error: OnError.new(on_error)}
      %{name: nil, on_error: nil} -> %{t | name: name, on_error: OnError.new(on_error)}
      _ -> build(name, on_error, t)
    end
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

  @spec on_error(t, on_error) :: t
  def on_error(%__MODULE__{} = pipeline, on_error) do
    %__MODULE__{pipeline | on_error: OnError.new(on_error)}
  end

  @spec chain(t(input, in_between), t(in_between, output)) :: t(input, output)
        when input: any, in_between: any, output: any
  # Minor optimization: merge unnamed pipelines without error handling into the current pipeline
  def chain(%__MODULE__{} = left, %__MODULE__{name: nil, on_error: nil} = right) do
    Map.update!(
      left,
      :reversed_steps,
      &Enum.concat(right.reversed_steps, &1)
    )
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

  @spec apply(t(input, output), Babel.data()) :: Babel.Applicable.result(output)
        when input: Babel.data(), output: any
  def apply(%__MODULE__{} = pipeline, data) do
    {reversed_traces, result} =
      pipeline.reversed_steps
      |> Enum.reverse()
      |> Enum.reduce_while({[], {:ok, data}}, fn applicable, {traces, {:ok, data}} ->
        trace = Trace.apply(applicable, data)
        traces = [trace | traces]

        cond do
          Trace.ok?(trace) ->
            {:cont, {traces, trace.result}}

          is_nil(pipeline.on_error) ->
            {:halt, {traces, trace.result}}

          true ->
            on_error_trace = Trace.apply(pipeline.on_error, Error.new(trace))

            {:halt, {[on_error_trace | traces], on_error_trace.result}}
        end
      end)

    {Enum.reverse(reversed_traces), result}
  end

  defimpl Babel.Applicable do
    defdelegate apply(pipeline, data), to: Babel.Pipeline
  end
end
