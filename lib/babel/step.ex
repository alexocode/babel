defmodule Babel.Step do
  # module = inspect(__MODULE__)
  import Kernel, except: [apply: 2]

  @type t :: t()
  @type t(output) :: t(term, output)
  @type t(input, output) :: %__MODULE__{
          name: name(),
          function: step_fun(input, output)
        }
  defstruct [:function, :name]

  @typedoc "A term describing what this step does"
  @type name :: Babel.name()

  @type step_fun :: step_fun(any, any)
  @type step_fun(input, output) :: (input -> result(output))

  @type result(output) :: output | {:ok, output} | :error | {:error, reason :: any}

  defguard is_step_function(function) when is_function(function, 1)

  @spec new(name, step_fun(input, output)) :: t(input, output) when input: any, output: any
  def new(name, function) when is_function(function, 1) do
    %__MODULE__{name: name, function: function}
  end

  @spec apply(t(input, output), Babel.data()) :: {:ok, output} | {:error, Babel.Error.t()}
        when input: any, output: any
  def apply(%__MODULE__{} = step, data) do
    data
    |> step.function.()
    |> Babel.Error.wrap_if_error(data, step)
    |> case do
      {:error, error} ->
        {:error, error}

      {:ok, data} ->
        {:ok, data}

      data ->
        {:ok, data}
    end
  rescue
    error ->
      {:error, Babel.Error.wrap(error, data, step)}
  end

  defimpl Babel.Applicable do
    defdelegate apply(step, data), to: Babel.Step
  end
end
