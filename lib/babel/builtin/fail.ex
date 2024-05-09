defmodule Babel.Builtin.Fail do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:reason]
  defstruct [:reason]

  def new(reason) do
    %__MODULE__{reason: reason}
  end

  @impl Babel.Step
  def apply(%__MODULE__{reason: reason}, %Babel.Context{}) do
    {:error, reason}
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:reason], opts)
  end
end
