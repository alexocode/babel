defmodule Babel.Error do
  alias Babel.Trace

  @type t :: t(any)
  @type t(reason) :: %__MODULE__{reason: reason, trace: Trace.t()}
  defexception [:reason, :trace]

  @spec new(Trace.t({:error, reason})) :: t(reason) when reason: any
  def new(%Trace{} = trace) do
    %__MODULE__{
      reason: determine_reason(trace.output),
      trace: trace
    }
  end

  defp determine_reason(:error), do: :unknown
  defp determine_reason({:error, reason}), do: determine_reason(reason)
  defp determine_reason(other_reason), do: other_reason

  @impl true
  def message(%__MODULE__{reason: reason, trace: trace}) do
    """
    #{babel(trace.babel)} failed to transform data: #{inspect(reason)}

    #{trace(trace)}
    """
  end

  defp babel(%struct{name: name}) do
    "#{inspect(struct)}<#{name(name)}>"
  end

  defp babel(other), do: inspect(other)

  defp name(nil), do: ""
  defp name(term), do: inspect(term)

  defp trace(%Babel.Trace{} = trace) do
    inspect(trace, custom_options: [indent: 2])
  end
end
