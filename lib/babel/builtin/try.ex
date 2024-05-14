defmodule Babel.Builtin.Try do
  @moduledoc false
  use Babel.Step, inspect: true

  alias Babel.Applicable
  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Trace

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
    Enum.all?(list, &(not is_nil(Babel.Applicable.impl_for(&1))))
  end

  @impl Babel.Step
  def apply(%__MODULE__{applicables: applicables, default: default} = step, %Context{} = context) do
    {nested, output} =
      Trace.Nesting.traced_reduce_while(
        applicables,
        &Applicable.apply(&1, context),
        {:error, []},
        fn
          {:ok, value}, _errors -> {:halt, {:ok, value}}
          {:error, _} = e, errors -> {:cont, Trace.Nesting.collect_errors(e, errors)}
        end
      )

    result =
      case {default, output} do
        {_, {:ok, value}} -> {:ok, value}
        {@no_default, {:error, reasons}} -> {:error, reasons}
        {default, {:error, _}} -> {:ok, default}
      end

    Trace.new(step, context, result, nested)
  end

  @impl Babel.Step
  def inspect(%__MODULE__{default: @no_default} = step, opts) do
    Builtin.inspect(step, [:applicables], opts)
  end

  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:applicables, :default], opts)
  end
end
