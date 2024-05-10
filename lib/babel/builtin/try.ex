defmodule Babel.Builtin.Try do
  @moduledoc false
  use Babel.Step

  @no_default {__MODULE__, :no_default}

  @enforce_keys [:applicables]
  defstruct [:applicables, {:default, @no_default}]

  def new(applicables, default \\ @no_default) do
    wrapped_applicables = List.wrap(applicables)

    unless list_of_applicables?(wrapped_applicables) do
      raise ArgumentError, "not a list of Babel.Applicable: #{inspect(applicables)}"
    end

    %__MODULE__{applicables: wrapped_applicables, default: default}
  end

  defp list_of_applicables?(list) do
    is_list(list) and Enum.all?(list, &(not is_nil(Babel.Applicable.impl_for(&1))))
  end

  @impl Babel.Step
  def apply(%__MODULE__{} = step, %Babel.Context{} = context) do
    {nested, output} = do_try(step, context)

    Babel.Trace.new(step, context, output, nested)
  end

  defp do_try(%{applicables: applicables, default: @no_default}, context) do
    do_try(applicables, context, [], [])
  end

  defp do_try(%{applicables: applicables, default: default}, context) do
    case do_try(applicables, context, [], []) do
      {nested, {:error, _}} -> {nested, {:ok, default}}
      {nested, ok} -> {nested, ok}
    end
  end

  defp do_try([], _input, nested, errors) do
    {Enum.reverse(nested), {:error, Enum.reverse(errors)}}
  end

  defp do_try([applicable | rest], context, nested, errors) do
    trace = Babel.Applicable.apply(applicable, context)
    nested = [trace | nested]

    case Babel.Trace.result(trace) do
      {:ok, value} ->
        {Enum.reverse(nested), {:ok, value}}

      {:error, reason} ->
        do_try(rest, context, nested, [reason | errors])
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
