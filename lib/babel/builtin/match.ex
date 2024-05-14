defmodule Babel.Builtin.Match do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context

  @enforce_keys [:matcher]
  defstruct [:matcher]

  def new(matcher) do
    unless is_function(matcher, 1) do
      raise ArgumentError, "not an arity 1 function: #{inspect(matcher)}"
    end

    %__MODULE__{matcher: matcher}
  end

  @impl Babel.Step
  def apply(%__MODULE__{matcher: matcher} = step, %Context{data: data} = context) do
    nested = Babel.Applicable.apply(matcher.(data), context)

    Babel.Trace.new(step, data, nested.output, [nested])
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:matcher], opts)
  end
end
