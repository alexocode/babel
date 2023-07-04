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
  @type name() :: Babel.name()

  @type step_fun :: step_fun(any, any)
  @type step_fun(input, output) :: (input -> result(output))

  @type result(output) :: output | {:ok, output} | :error | {:error, reason :: any}

  defguard is_step_function(function) when is_function(function, 1)

  @spec new(name, step_fun(input, output)) :: t(input, output) when input: any, output: any
  def new(name, function) when is_function(function, 1) do
    %__MODULE__{name: name, function: function}
  end

  # TODO: Add docs
  @spec wrap(module, function_name :: atom, args :: list) :: t()
  def wrap(module, function_name, args)
      when is_atom(module) and is_atom(function_name) and is_list(args) do
    unless function_exported?(module, function_name, 1 + length(args)) do
      raise ArgumentError,
            "Invalid function spec: `#{inspect(module)}.#{function_name}/#{1 + length(args)}` doesn't seem to exist"
    end

    new({module, function_name}, &Kernel.apply(module, function_name, [&1 | args]))
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

  defimpl Babel.Applicable do
    def apply(step, data), do: Babel.Step.apply(step, data)
  end
end
