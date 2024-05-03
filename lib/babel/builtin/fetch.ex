defmodule Babel.Builtin.Fetch do
  @moduledoc false

  def call(data, path) do
    path
    |> List.wrap()
    |> Enum.reduce_while({:ok, data}, fn path_segment, {:ok, next} ->
      case Babel.Fetchable.fetch(next, path_segment) do
        {:ok, next} ->
          {:cont, {:ok, next}}

        :error ->
          {:halt, {:error, {:not_found, path_segment}}}
      end
    end)
  end
end
