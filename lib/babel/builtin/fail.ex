defmodule Babel.Builtin.Fail do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context

  @enforce_keys [:reason]
  defstruct [:reason]

  def new(reason) do
    %__MODULE__{reason: reason}
  end

  @impl Babel.Step
  def apply(%__MODULE__{reason: reason_fn}, %Context{data: data})
      when is_function(reason_fn, 1) do
    {:error, reason_fn.(data)}
  end

  def apply(%__MODULE__{reason: reason}, %Context{}) do
    {:error, reason}
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:reason], opts)
  end
end
