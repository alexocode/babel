defmodule Babel.Test.ContextStep do
  @moduledoc false
  use Babel.Step

  defstruct [:function]

  def new(function) when is_function(function, 1) do
    %__MODULE__{function: function}
  end

  @impl true
  def apply(%__MODULE__{function: function}, %Babel.Context{} = context) do
    function.(context)
  end
end
