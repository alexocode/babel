defmodule Babel.Builtin.Identity do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context

  defstruct []

  def new do
    %__MODULE__{}
  end

  @impl Babel.Step
  def apply(%__MODULE__{}, %Context{data: data}) do
    data
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [], opts)
  end
end
