defmodule Babel.Builtin.Cast do
  @moduledoc false
  use Babel.Step

  @allowed_types [:boolean, :float, :integer]

  @enforce_keys [:type]
  defstruct [:type]

  # TODO: Raise ArgumentError
  def new(type) when type in @allowed_types do
    %__MODULE__{type: type}
  end

  @impl Babel.Step
  def apply(%__MODULE__{type: type}, %Babel.Context{current: data}) do
    cast(type, data)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:type], opts)
  end

  defp cast(:boolean, boolean) when is_boolean(boolean) do
    {:ok, boolean}
  end

  defp cast(:boolean, binary) when is_binary(binary) do
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

  defp cast(:float, float) when is_float(float) do
    {:ok, float}
  end

  defp cast(:float, integer) when is_integer(integer) do
    {:ok, integer / 1}
  end

  defp cast(:float, binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} when is_float(float) ->
        {:ok, float}

      _other ->
        {:error, {:invalid, :float, binary}}
    end
  end

  defp cast(:integer, integer) when is_integer(integer) do
    {:ok, integer}
  end

  defp cast(:integer, float) when is_float(float) do
    {:ok, trunc(float)}
  end

  defp cast(:integer, binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {integer, ""} when is_integer(integer) ->
        {:ok, integer}

      _other ->
        {:error, {:invalid, :integer, binary}}
    end
  end

  defp cast(type, unexpected) do
    {:error, {:invalid, type, unexpected}}
  end
end
