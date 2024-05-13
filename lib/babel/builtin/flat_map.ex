defmodule Babel.Builtin.FlatMap do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:mapper]
  defstruct [:mapper]

  def new(mapper) do
    %__MODULE__{mapper: mapper}
  end

  @impl Babel.Step
  def apply(%__MODULE__{mapper: mapper} = step, %Babel.Context{current: enum} = context) do
    {nested, result} =
      Babel.Trace.Nesting.map_nested(
        enum,
        &Babel.Applicable.apply(mapper.(&1), %Babel.Context{context | current: &1})
      )

    Babel.Trace.new(step, enum, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:mapper], opts)
  end
end
