defmodule Babel.Pipeline do
  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(_input, _output) :: %__MODULE__{
          name: name,
          steps_in_reverse_order: [step]
        }
  defstruct name: nil,
            steps_in_reverse_order: []

  @typedoc "A term describing what this pipeline does"
  @type name() :: term
  @type step() :: Babel.Applicable.t()

  @spec new(name) :: t
  @spec new(name, steps :: [step]) :: t
  def new(name, steps \\ []) do
    %__MODULE__{
      name: name,
      steps_in_reverse_order: Enum.reverse(steps)
    }
  end

  @doc "Alias for `new/1`."
  @spec begin(name) :: t
  def begin(name), do: new(name)

  @spec chain(t, step | [step]) :: t
  def chain(%__MODULE__{} = pipeline, step_or_steps) do
    reversed_steps =
      step_or_steps
      |> List.wrap()
      |> Enum.reverse()

    Map.update!(pipeline, :steps_in_reverse_order, &Enum.concat(reversed_steps, &1))
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
          # TODO: Add further error context
          {:halt, {:error, error}}
      end
    end)
  end

  defimpl Babel.Applicable do
    def apply(pipeline, data), do: Babel.Pipeline.apply(pipeline, data)
  end
end
