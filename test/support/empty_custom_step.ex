defmodule Babel.Test.EmptyCustomStep do
  @moduledoc false
  use Babel.Step

  defstruct []

  @impl true
  def apply(%__MODULE__{}, _) do
    {:ok, 42}
  end
end
