defmodule Babel.Builtin.Const do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context

  @enforce_keys [:value]
  defstruct [:value]

  def new(const) do
    %__MODULE__{value: const}
  end

  @impl Babel.Step
  def apply(%__MODULE__{value: value}, %Context{}) do
    {:ok, value}
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:value], opts)
  end
end
