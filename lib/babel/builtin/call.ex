defmodule Babel.Builtin.Call do
  @moduledoc false
  use Babel.Step

  alias Babel.Builtin
  alias Babel.Context
  alias Babel.Trace

  require Babel.Trace.Nesting

  @enforce_keys [:module, :function]
  defstruct [:module, :function, {:extra_args, []}]

  def new(module, function, extra_args \\ [])
      when is_atom(module) and is_atom(function) and is_list(extra_args) do
    unless Code.ensure_loaded?(module) and
             function_exported?(module, function, 1 + length(extra_args)) do
      raise ArgumentError,
            "cannot call missing function `#{inspect(module)}.#{function}/#{1 + length(extra_args)}`"
    end

    %__MODULE__{module: module, function: function, extra_args: extra_args}
  end

  @impl Babel.Step
  def apply(%__MODULE__{} = call, %Context{current: input}) do
    Trace.Nesting.traced_try call, input do
      Kernel.apply(call.module, call.function, [input | call.extra_args])
    end
  end

  @impl Babel.Step
  def inspect(%__MODULE__{extra_args: []} = step, opts) do
    Builtin.inspect(step, [:module, :function], opts)
  end

  def inspect(%__MODULE__{} = step, opts) do
    Builtin.inspect(step, [:module, :function, :extra_args], opts)
  end
end
