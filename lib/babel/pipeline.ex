defmodule Babel.Pipeline do
  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(_input, output) :: %__MODULE__{
          name: name,
          steps_in_reverse_order: [step],
          on_error: nil | on_error(output)
        }
  defstruct name: nil,
            steps_in_reverse_order: [],
            on_error: nil

  @typedoc "A term describing what this pipeline does"
  @type name() :: Babel.name()
  @type step() :: Babel.Applicable.t()
  @type on_error :: on_error(term)
  @type on_error(output) :: (Babel.Error.t() -> Babel.Step.result(output))

  defguardp is_valid_on_error(value) when is_nil(value) or is_function(value, 1)

  @spec new(step | [step]) :: t
  @spec new(name, step | [step]) :: t
  @spec new(name, on_error | nil, step | [step]) :: t
  def new(name \\ nil, on_error \\ nil, step_or_steps)

  def new(name, on_error, steps) when is_list(steps) and is_valid_on_error(on_error) do
    %__MODULE__{
      name: name,
      on_error: on_error,
      steps_in_reverse_order: Enum.reverse(steps)
    }
  end

  # Reuse the given pipeline but only when name and error handling are the same (probably nil)
  def new(name, on_error, %__MODULE__{name: name, on_error: on_error} = pipeline)
      when is_valid_on_error(on_error) do
    pipeline
  end

  def new(name, on_error, step) when is_valid_on_error(on_error) do
    %__MODULE__{name: name, on_error: on_error, steps_in_reverse_order: [step]}
  end

  @spec named(t, name) :: t
  def named(%__MODULE__{} = pipeline, name) when not is_nil(name) do
    %__MODULE__{pipeline | name: name}
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
      :steps_in_reverse_order,
      &Enum.concat(right.steps_in_reverse_order, &1)
    )
  end

  @spec chain(t, [step]) :: t
  def chain(%__MODULE__{} = pipeline, steps) when is_list(steps) do
    Map.update!(
      pipeline,
      :steps_in_reverse_order,
      &Enum.concat(Enum.reverse(steps), &1)
    )
  end

  @spec chain(t, step) :: t
  def chain(%__MODULE__{} = pipeline, step) do
    Map.update!(
      pipeline,
      :steps_in_reverse_order,
      &[step | &1]
    )
  end

  @spec apply(t(input, output), Babel.data()) :: {:ok, output} | {:error, Babel.Error.t()}
        when input: Babel.data(), output: any
  def apply(%__MODULE__{} = pipeline, data) do
    pipeline.steps_in_reverse_order
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
