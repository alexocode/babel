defmodule Babel.Builtin.Try do
  @moduledoc false

  def call([], input), do: {:ok, input}
  def call(applicables, input), do: do_call(applicables, input, [], [])

  defp do_call([], _input, traces, errors) do
    {Enum.reverse(traces), {:error, Enum.reverse(errors)}}
  end

  defp do_call([applicable | rest], input, traces, errors) do
    trace = Babel.Trace.apply(applicable, input)
    traces = [trace | traces]

    case trace.output do
      {:ok, value} ->
        {Enum.reverse(traces), {:ok, value}}

      {:error, reason} ->
        do_call(rest, input, traces, [reason | errors])
    end
  end
end
