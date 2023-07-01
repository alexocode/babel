defmodule Babel.Step do
  # module = inspect(__MODULE__)
  import Kernel, except: [apply: 2]

  @type t :: t()
  @type t(input) :: t(input, any)
  @type t(input, output) :: %__MODULE__{
          name: name(),
          function: step_fun(input, output)
        }
  defstruct [:function, :name]

  @typedoc "A term describing what this step does"
  @type name() :: term

  @type step_fun :: step_fun(any, any)
  @type step_fun(input, output) ::
          (input -> output | {:ok, output} | :error | {:error, reason :: any})

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
    |> Babel.Error.maybe_wrap_error(data: data, step: step)
    |> case do
      {:error, error} ->
        {:error, error}

      {:ok, data} ->
        {:ok, data}

      data ->
        {:ok, data}
    end
  end

  @spec chain(list(t)) :: Step.t()
  def chain(list) when is_list(list) do
    names = Enum.map(list, & &1.name)

    new(
      {:chain, names},
      &Enum.reduce_while(list, {:ok, &1}, fn step, {:ok, data} ->
        case apply(step, data) do
          {:ok, result} ->
            {:cont, {:ok, result}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
      end)
    )
  end
end
