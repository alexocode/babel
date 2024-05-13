defmodule Babel.Builtin.FlatMap do
  @moduledoc false
  use Babel.Step

  alias Babel.Applicable
  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Trace

  @enforce_keys [:mapper]
  defstruct [:mapper]

  def new(mapper) do
    %__MODULE__{mapper: mapper}
  end

  @impl Babel.Step
  def apply(%__MODULE__{mapper: mapper} = step, %Context{current: enum} = context) do
    {nested, result} =
      Trace.Nesting.traced_map(
        enum,
        &Applicable.apply(mapper.(&1), %Context{context | current: &1})
      )

    Trace.new(step, enum, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:mapper], opts)
  end
end
