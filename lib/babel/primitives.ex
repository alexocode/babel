defmodule Babel.Primitives do
  @moduledoc false

  def fetch(data, path) do
    path
    |> List.wrap()
    |> Enum.reduce_while({:ok, data}, fn path_segment, {:ok, next} ->
      case Babel.Fetchable.fetch(next, path_segment) do
        {:ok, next} ->
          {:cont, {:ok, next}}

        :error ->
          # TODO: Better erroring
          {:halt, {:error, %Babel.Error{}}}
      end
    end)
  end

  def get(data, path, default \\ nil) do
    case fetch(data, path) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end

  def get!(data, path) do
    case fetch(data, path) do
      {:ok, value} -> value
      {:error, error} -> raise error
    end
  end
end
