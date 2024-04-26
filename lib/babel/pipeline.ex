defmodule Babel.Pipeline do
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
  @type on_error(output) :: (Babel.Error.t() -> Babel.Step.result(output))

  @spec new(step | [step]) :: t
  def new(%__MODULE__{} = t), do: t
  def new(steps), do: build(steps)

  @spec new(name, step | [step]) :: t
  def new(name, %__MODULE__{name: name} = t), do: t
  def new(name, steps), do: build(name, steps)

  @spec new(name, on_error, step | [step]) :: t
  def new(name, on_error, %__MODULE__{name: name, on_error: on_error} = t), do: t
  def new(name, on_error, %__MODULE__{name: name, on_error: nil} = t), do: on_error(t, on_error)
  def new(name, on_error, steps), do: build(name, on_error, steps)

  defp build(name \\ nil, on_error \\ nil, step_or_steps) do
    %__MODULE__{
      name: name,
      on_error: on_error,
      reversed_steps:
        step_or_steps
        |> List.wrap()
        |> Enum.reverse()
    }
  end

  @spec on_error(t, on_error) :: t
  def on_error(%__MODULE__{} = pipeline, on_error) when is_function(on_error, 1) do
    %__MODULE__{pipeline | on_error: on_error}
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

  @spec apply(t(input, output), Babel.data()) :: {:ok, output} | {:error, Babel.Error.t()}
        when input: Babel.data(), output: any
  def apply(%__MODULE__{} = pipeline, data) do
    pipeline.reversed_steps
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, data}, fn applicable, {:ok, result} ->
      case Babel.Applicable.apply(applicable, result) do
        {:ok, result} ->
          {:cont, {:ok, result}}

        {:error, error} ->
          wrapped_error = Babel.Error.wrap(error, data, pipeline)

          maybe_error =
            if pipeline.on_error do
              wrapped_error
              |> pipeline.on_error.()
              # TODO: Retain stack trace (somehow)
              |> Babel.Error.wrap_if_error(data, pipeline)
            else
              wrapped_error
            end

          {:halt, maybe_error}
      end
    end)
  end

  defimpl Babel.Applicable do
    defdelegate apply(pipeline, data), to: Babel.Pipeline
  end
end
