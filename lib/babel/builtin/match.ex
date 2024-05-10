defmodule Babel.Builtin.Match do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:matcher]
  defstruct [:matcher]

  def new(matcher) do
    %__MODULE__{matcher: matcher}
  end

  @impl Babel.Step
  def apply(%__MODULE__{matcher: matcher} = step, %Babel.Context{current: input}) do
    nested = Babel.Applicable.apply(matcher.(input), input)

    Babel.Trace.new(step, input, nested.output, [nested])
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:value], opts)
  end
end
