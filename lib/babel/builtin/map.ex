defmodule Babel.Builtin.Map do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:applicable]
  defstruct [:applicable]

  def new(applicable) do
    unless Babel.Applicable.impl_for(applicable) do
      raise ArgumentError, "not a Babel.Applicable: #{inspect(applicable)}"
    end

    %__MODULE__{applicable: applicable}
  end

  @impl Babel.Step
  def apply(%__MODULE__{applicable: applicable} = step, %Babel.Context{current: enum} = context) do
    {nested, result} =
      Babel.Trace.Nesting.map_nested(
        enum,
        &Babel.Applicable.apply(applicable, %Babel.Context{context | current: &1})
      )

    Babel.Trace.new(step, enum, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:applicable], opts)
  end
end
