defmodule Babel.Builtin.Get do
  use Babel.Step

  @enforce_keys [:path]
  defstruct [:path, :default]

  def new(path, default \\ nil) do
    %__MODULE__{path: path, default: default}
  end

  @impl Babel.Step
  def apply(%__MODULE__{path: path, default: default}, %Babel.Context{current: data}) do
    path
    |> List.wrap()
    |> Enum.reduce_while({:ok, data}, fn path_segment, {:ok, next} ->
      case Babel.Fetchable.fetch(next, path_segment) do
        {:ok, next} ->
          {:cont, {:ok, next}}

        :error ->
          {:halt, {:ok, default}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{default: nil} = step, opts) do
    Babel.Builtin.inspect(step, [:path], opts)
  end

  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:path, :default], opts)
  end
end
