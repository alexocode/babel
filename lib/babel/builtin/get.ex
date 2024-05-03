defmodule Babel.Builtin.Get do
  @moduledoc false

  alias Babel.Builtin.Fetch

  def call(data, path, default) do
    case Fetch.call(data, path) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end
end
