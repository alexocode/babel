defmodule Babel.Builtin.Cast do
  @moduledoc false

  def call(:boolean, boolean) when is_boolean(boolean) do
    {:ok, boolean}
  end

  def call(:boolean, binary) when is_binary(binary) do
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

  def call(:float, float) when is_float(float) do
    {:ok, float}
  end

  def call(:float, integer) when is_integer(integer) do
    {:ok, integer / 1}
  end

  def call(:float, binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} when is_float(float) ->
        {:ok, float}

      _other ->
        {:error, {:invalid, :float, binary}}
    end
  end

  def call(:integer, integer) when is_integer(integer) do
    {:ok, integer}
  end

  def call(:integer, float) when is_float(float) do
    {:ok, trunc(float)}
  end

  def call(:integer, binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {integer, ""} when is_integer(integer) ->
        {:ok, integer}

      _other ->
        {:error, {:invalid, :integer, binary}}
    end
  end

  def call(type, unexpected) do
    {:error, {:invalid, type, unexpected}}
  end
end
