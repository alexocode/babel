defmodule Babel.Builtin.Fetch do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Fetchable

  @enforce_keys [:path]
  defstruct [:path]

  def new(path) do
    %__MODULE__{path: path}
  end

  @impl Babel.Step
  def apply(%__MODULE__{path: path}, %Context{data: data}) when is_list(path) do
    Enum.reduce_while(path, {:ok, data}, fn path_segment, {:ok, next} ->
      case do_fetch(next, path_segment) do
        {:ok, next} -> {:cont, {:ok, next}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def apply(%__MODULE__{path: path_segment}, %Context{data: data}) do
    do_fetch(data, path_segment)
  end

  defp do_fetch(data, path_segment) do
    case Fetchable.fetch(data, path_segment) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error, {:not_found, path_segment}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:path], opts)
  end
end
