defmodule Babel.Step do
  @moduledoc """
  This module is meant to be used to create your own `Babel` custom steps,
  and is used internally to create all of `Babel`'s built-in steps.

  It's required that any module which `use`s `Babel.Step` defines a struct.

  ## What happens when I `use Babel.Step`?

  Your struct will:

  1. implement the `Babel.Step` behaviour (`c:apply/2`)
  2. implement the `Babel.Applicable` protocol, whose invocations delegate to `c:apply/2`

  ## Inspect

  If you'd like to customize the `inspect/2` rendition of your custom `Babel.Step`,
  you can `use Babel.Step, inspect: true`; this will implement the `Inspect` protocol
  and delegate all invocations to `c:inspect/2`.
  """

  @typedoc "An implementation of this behaviour."
  @type t :: t(any)
  @typedoc "An implementation of this behaviour whose `apply/2` function produces the specified output."
  @type t(output) :: t(any, output)
  @typedoc "An implementation of this behaviour whose `apply/2` function accepts the given input and produces the specified output."
  @type t(_input, _output) :: any

  @type result(output) :: output | {:ok, output} | :error | {:error, reason :: any}
  @type result_or_trace(output) :: result(output) | Babel.Trace.t(output)

  # coveralls-ignore-start
  defmacro __using__(opts) do
    quote generated: true, location: :keep do
      import Kernel, except: [apply: 2]

      @behaviour Babel.Step

      unquote(impl_applicable(__CALLER__))
      unquote(impl_inspect(__CALLER__, opts[:inspect]))
    end
  end

  defp impl_applicable(%{module: module}) do
    quote generated: true, location: :keep do
      defimpl Babel.Applicable do
        def apply(step, context) do
          Babel.Telemetry.span(
            [:babel, :step],
            %{babel: step, input: context},
            fn ->
              trace_or_result =
                try do
                  unquote(module).apply(step, context)
                rescue
                  error in [Babel.Error] -> error.trace
                  other -> {:error, other}
                end

              trace =
                case trace_or_result do
                  %Babel.Trace{} = trace -> trace
                  result -> Babel.Trace.new(step, context, result)
                end

              {trace,
               %{
                 babel: step,
                 input: context,
                 trace: trace,
                 result: if(Babel.Trace.ok?(trace), do: :ok, else: :error)
               }}
            end
          )
        end
      end
    end
  end

  defp impl_inspect(%{module: module}, true) do
    quote do
      defimpl Inspect do
        defdelegate inspect(step, opts), to: unquote(module)
      end
    end
  end

  defp impl_inspect(_env, _false), do: nil

  # coveralls-ignore-stop

  @callback apply(t(output), Babel.Context.t()) :: result_or_trace(output) when output: any
  @callback inspect(t, Inspect.Opts.t()) :: Inspect.Algebra.t()

  @optional_callbacks inspect: 2
end
