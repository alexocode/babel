defmodule Babel.Builtin.Map do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:applicable]
  defstruct [:applicable]

  def new(applicable) do
    %__MODULE__{applicable: applicable}
  end

  @impl Babel.Step
  def apply(%__MODULE__{applicable: applicable} = step, %Babel.Context{current: enum} = context) do
    {nested, result} =
      Utils.map_nested(
        enum,
        &Babel.Applicable.apply(applicable, %Babel.Context{context | current: &1})
      )

    %Babel.Trace{
      babel: step,
      input: enum,
      output: result,
      nested: nested
    }
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:applicable], opts)
  end
end
