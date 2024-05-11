defmodule Babel.Builtin.Fetch do
  @moduledoc false
  use Babel.Step

  @enforce_keys [:path]
  defstruct [:path]

  def new(path) do
    %__MODULE__{path: path}
  end

  @impl Babel.Step
  def apply(%__MODULE__{path: path}, %Babel.Context{current: data}) do
    path
    |> List.wrap()
    |> Enum.reduce_while({:ok, data}, fn path_segment, {:ok, next} ->
      case Babel.Fetchable.fetch(next, path_segment) do
        {:ok, next} ->
          {:cont, {:ok, next}}

        :error ->
          {:halt, {:error, {:not_found, path_segment}}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:path], opts)
  end
end
