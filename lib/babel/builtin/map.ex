defmodule Babel.Builtin.Map do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Applicable
  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Trace

  @enforce_keys [:applicable]
  defstruct [:applicable]

  def new(applicable) do
    unless Applicable.impl_for(applicable) do
      raise ArgumentError, "not a Babel.Applicable: #{inspect(applicable)}"
    end

    %__MODULE__{applicable: applicable}
  end

  @impl Babel.Step
  def apply(%__MODULE__{applicable: applicable} = step, %Context{data: enum} = context) do
    {nested, result} =
      Trace.Nesting.traced_map(
        enum,
        &Applicable.apply(applicable, %Context{context | data: &1})
      )

    Trace.new(step, enum, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:applicable], opts)
  end
end
