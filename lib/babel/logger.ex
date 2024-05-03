defmodule Babel.Logger do
  @moduledoc false
  defmacro warning(message, metadata \\ []) do
    if elixir_version?("~> 1.11") do
      quote do
        require Logger
        Logger.warning("[Babel] " <> unquote(message), unquote(metadata))
      end
    else
      quote do
        require Logger
        Logger.warn("[Babel] " <> unquote(message), unquote(metadata))
      end
    end
  end

  defp elixir_version?(version_spec), do: Version.match?(System.version(), version_spec)
end
