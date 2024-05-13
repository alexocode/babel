defmodule Babel.Test.EmptyCustomStep do
  use Babel.Step

  defstruct []

  @impl true
  def apply(%__MODULE__{}, _) do
    {:ok, 42}
  end
end
