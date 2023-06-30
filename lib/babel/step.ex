defmodule Babel.Step do
  # module = inspect(__MODULE__)

  @type t :: t(any)
  @type t(output) :: t(any, output)
  @type t(input, output) :: t(input, any, output)
  @type t(input, in_between, output) :: %__MODULE__{
          depth: pos_integer(),
          function: step_fun(input, in_between),
          next: nil | t(in_between, output)
        }
  defstruct [:depth, :function, :next]

  @type step_fun :: step_fun(any, any)
  @type step_fun(input, output) ::
          (input -> output | {:ok, output} | :error | {:error, reason :: any})

  @type data :: any

  @spec new(step_fun(input, output)) :: t(input, output) when input: any, output: any
  def new(function) when is_function(function, 1) do
    %__MODULE__{depth: 1, function: function}
  end

  @spec concat(left :: t(a, b), right :: t(b, c)) :: t(a, b, c) when a: any, b: any, c: any
  def concat(%__MODULE__{next: nil} = left, %__MODULE__{} = right) do
    %__MODULE__{left | depth: right.depth + 1, next: right}
  end

  def concat(%__MODULE__{} = left, %__MODULE__{} = right) do
    next = concat(left.next, right)

    %__MODULE__{left | depth: next.depth + 1, next: next}
  end

  @spec apply(t(output), data) :: {:ok, output} | {:error, Babel.Error.t()} when output: any
  def apply(%__MODULE__{} = step, data) do
    Enum.reduce_while(step, {:ok, data}, fn step, {:ok, data} ->
      case apply_one(step, data) do
        {:ok, value} ->
          {:cont, {:ok, value}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  @spec apply_one(t(output), data) :: {:ok, output} | {:error, Babel.Error.t()} when output: any
  def apply_one(%__MODULE__{} = step, data) do
    data
    |> step.function.()
    |> Babel.Error.maybe_wrap_error(data)
    |> case do
      {:error, error} ->
        {:error, error}

      {:ok, data} ->
        {:ok, data}

      data ->
        {:ok, data}
    end
  end
end
