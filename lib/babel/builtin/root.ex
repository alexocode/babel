defmodule Babel.Builtin.Root do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context

  defstruct []

  def new do
    %__MODULE__{}
  end

  @impl Babel.Step
  def apply(%__MODULE__{}, %Context{data: data, history: []}) do
    data
  end

  def apply(%__MODULE__{}, %Context{history: history}) do
    List.last(history).input
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [], opts)
  end
end
