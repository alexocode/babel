defmodule Babel.Builtin.Identity do
  @moduledoc false
  use Babel.Step, inspect: true

  defstruct []

  def new do
    %__MODULE__{}
  end

  @impl Babel.Step
  def apply(%__MODULE__{}, %Babel.Context{current: current}) do
    current
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [], opts)
  end
end
