defmodule Babel.Builtin.Then do
  @moduledoc false
  use Babel.Step

  require Babel.Utils

  @enforce_keys [:function]
  defstruct [:name, :function]

  def new(name \\ nil, function) when is_function(function, 1) do
    %__MODULE__{name: name, function: function}
  end

  @impl Babel.Step
  def apply(%__MODULE__{function: function}, %Babel.Context{current: input}) do
    Babel.Utils.trace_try do
      function.(input)
    end
  end

  @impl Babel.Step
  def inspect(%__MODULE__{name: nil} = then, opts) do
    Babel.Builtin.inspect(then, [:function], opts)
  end

  def inspect(%__MODULE__{} = then, opts) do
    Babel.Builtin.inspect(then, [:name, :function], opts)
  end
end
