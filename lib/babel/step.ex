defmodule Babel.Step do
  @moduledoc """
  TODO: Write
  """

  @typedoc "An implementation of this behaviour."
  @type t :: t(any)
  @typedoc "An implementation of this behaviour whose `apply/2` function produces the specified output."
  @type t(output) :: t(any, output)
  @typedoc "An implementation of this behaviour whose `apply/2` function accepts the given input and produces the specified output."
  @type t(_input, _output) :: any

  @type result(output) :: output | {:ok, output} | :error | {:error, reason :: any}
  @type result_or_trace(output) :: result(output) | Babel.Trace.t(output)

  defmacro __using__(_) do
    %{module: module} = __CALLER__

    quote generated: true do
      import Kernel, except: [apply: 2]

      @behaviour Babel.Step

      @impl Babel.Step
      defdelegate inspect(step, opts), to: Inspect.Any

      defoverridable inspect: 2

      defimpl Babel.Applicable do
        def apply(step, context) do
          case unquote(module).apply(step, context) do
            %Babel.Trace{} = trace ->
              trace

            result ->
              %Babel.Trace{
                babel: step,
                input: context.current,
                output: result
              }
          end
        end
      end

      defimpl Inspect do
        defdelegate inspect(step, opts), to: unquote(module)
      end
    end
  end

  @callback apply(t(output), Babel.Context.t()) :: result_or_trace(output) when output: any
  @callback inspect(t, Inspect.Opts.t()) :: Inspect.Algebra.t()

  @optional_callbacks inspect: 2
end
