defmodule Babel.Core.Primitives do
  @moduledoc false

  def fetch(data, path) do
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

  def get(data, path, default \\ nil) do
    case fetch(data, path) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end

  def cast(:boolean, boolean) when is_boolean(boolean) do
    {:ok, boolean}
  end

  def cast(:boolean, binary) when is_binary(binary) do
    binary
    |> String.trim()
    |> String.downcase()
    |> case do
      truthy when truthy in ["true", "yes"] ->
        {:ok, true}

      falsy when falsy in ["false", "no"] ->
        {:ok, false}

      _other ->
        {:error, {:invalid, :boolean, binary}}
    end
  end

  def cast(:float, float) when is_float(float) do
    {:ok, float}
  end

  def cast(:float, integer) when is_integer(integer) do
    {:ok, integer / 1}
  end

  def cast(:float, binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} when is_float(float) ->
        {:ok, float}

      _other ->
        {:error, {:invalid, :float, binary}}
    end
  end

  def cast(:integer, integer) when is_integer(integer) do
    {:ok, integer}
  end

  def cast(:integer, float) when is_float(float) do
    {:ok, trunc(float)}
  end

  def cast(:integer, binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {integer, ""} when is_integer(integer) ->
        {:ok, integer}

      _other ->
        {:error, {:invalid, :integer, binary}}
    end
  end

  def cast(type, unexpected) do
    {:error, {:invalid, type, unexpected}}
  end
end
