defmodule Babel.Builtin.Into do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Intoable
  alias Babel.Trace

  @enforce_keys [:intoable]
  defstruct [:intoable]

  def new(intoable) do
    %__MODULE__{intoable: intoable}
  end

  @impl Babel.Step
  def apply(%__MODULE__{intoable: intoable} = step, %Context{} = context) do
    {nested, result} = Intoable.into(intoable, context)

    Trace.new(step, context, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:intoable], opts)
  end
end
