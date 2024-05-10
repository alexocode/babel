defmodule Babel.Builtin.Into do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:intoable]
  defstruct [:intoable]

  def new(intoable) do
    %__MODULE__{intoable: intoable}
  end

  @impl Babel.Step
  def apply(%__MODULE__{intoable: intoable} = step, %Babel.Context{} = context) do
    {nested, result} = Babel.Intoable.into(intoable, context)

    Babel.Trace.new(step, context, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:intoable], opts)
  end
end
