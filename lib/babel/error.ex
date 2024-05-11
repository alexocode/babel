defmodule Babel.Error do
  alias Babel.Trace

  @type t :: t(any)
  @type t(reason) :: %__MODULE__{reason: reason, trace: Trace.t()}
  defexception [:reason, :trace]

  @spec new(Trace.t({:error, reason})) :: t(reason) when reason: any
  def new(%Trace{} = trace) do
    %__MODULE__{
      reason: determine_reason(trace),
      trace: trace
    }
  end

  defp determine_reason(%Trace{} = trace) do
    trace
    |> Trace.result()
    |> determine_reason()
  end

  defp determine_reason({:error, reason}), do: determine_reason(reason)
  defp determine_reason(other_reason), do: other_reason

  @impl true
  def message(%__MODULE__{reason: reason, trace: trace}) do
    """
    Failed to transform data: #{inspect(reason)}

    #{inspect(trace, custom_options: [indent: 2])}
    """
  end
end
