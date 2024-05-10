defmodule Babel.Builtin.Try do
  @moduledoc false
  use Babel.Step

  @no_default {__MODULE__, :no_default}

  @enforce_keys [:applicables]
  defstruct [:applicables, {:default, @no_default}]

  def new(applicables, default \\ @no_default) do
    %__MODULE__{applicables: applicables, default: default}
  end

  @impl Babel.Step
  def apply(%__MODULE__{} = step, %Babel.Context{current: input}) do
    {nested, output} = do_try(step, input)

    Babel.Trace.new(step, input, output, nested)
  end

  defp do_try(%{applicables: applicables, default: @no_default}, input) do
    do_try(applicables, input, [], [])
  end

  defp do_try(%{applicables: applicables, default: default}, input) do
    case do_try(applicables, input, [], []) do
      {nested, {:error, _}} -> {nested, {:ok, default}}
      {nested, ok} -> {nested, ok}
    end
  end

  defp do_try([], _input, nested, errors) do
    {Enum.reverse(nested), {:error, Enum.reverse(errors)}}
  end

  defp do_try([applicable | rest], input, nested, errors) do
    trace = Babel.Applicable.apply(applicable, input)
    nested = [trace | nested]

    case Babel.Trace.result(trace) do
      {:ok, value} ->
        {Enum.reverse(nested), {:ok, value}}

      {:error, reason} ->
        do_try(rest, input, nested, [reason | errors])
    end
  end

  @impl Babel.Step
  def inspect(%__MODULE__{default: @no_default} = step, opts) do
    Babel.Builtin.inspect(step, [:applicables], opts)
  end

  def inspect(%__MODULE__{} = step, opts) do
    Babel.Builtin.inspect(step, [:applicables, :default], opts)
  end
end
