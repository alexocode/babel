defmodule Babel.Builtin.Get do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Fetchable

  @enforce_keys [:path]
  defstruct [:path, :default]

  def new(path, default \\ nil) do
    %__MODULE__{path: path, default: default}
  end

  @impl Babel.Step
  def apply(%__MODULE__{path: path, default: default}, %Context{current: data})
      when is_list(path) do
    Enum.reduce_while(path, {:ok, data}, fn path_segment, {:ok, next} ->
      case Fetchable.fetch(next, path_segment) do
        {:ok, next} ->
          {:cont, {:ok, next}}

        :error ->
          {:halt, {:ok, default}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  def apply(%__MODULE__{path: path_segment, default: default}, %Context{current: data}) do
    case Fetchable.fetch(data, path_segment) do
      {:ok, next} ->
        {:ok, next}

      :error ->
        {:ok, default}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Babel.Step
  def inspect(%__MODULE__{default: nil} = step, opts) do
    Builtin.inspect(step, [:path], opts)
  end

  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:path, :default], opts)
  end
end
