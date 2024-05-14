defmodule Babel.Builtin.Then do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Trace.Nesting

  require Nesting

  @enforce_keys [:function]
  defstruct [:name, :function]

  def new(name \\ nil, function) do
    unless is_function(function, 1) do
      raise ArgumentError, "not an arity 1 function: #{inspect(function)}"
    end

    %__MODULE__{name: name, function: function}
  end

  @impl Babel.Step
  def apply(%__MODULE__{function: function} = then, %Context{current: input}) do
    Nesting.traced_try then, input do
      function.(input)
    end
  end

  @impl Babel.Step
  def inspect(%__MODULE__{name: nil} = then, opts) do
    Builtin.inspect(then, [:function], opts)
  end

  def inspect(%__MODULE__{} = then, opts) do
    Builtin.inspect(then, [:name, :function], opts)
  end
end
