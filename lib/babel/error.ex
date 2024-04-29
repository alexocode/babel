defmodule Babel.Error do
  alias Babel.Trace

  @type t :: t({:nested, [t]} | any)
  @type t(reason) :: %__MODULE__{reason: reason, trace: Trace.t()}
  defexception [:reason, :trace]

  @spec new(Trace.t({:error, reason})) :: t(reason) when reason: any
  def new(%Trace{} = trace) do
    %__MODULE__{
      reason: determine_reason(trace.result),
      trace: trace
    }
  end

  defp determine_reason(:error), do: :unknown
  defp determine_reason({:error, reason}), do: determine_reason(reason)
  defp determine_reason(%__MODULE__{} = nested), do: {:nested, [nested]}
  defp determine_reason([%__MODULE__{} | _] = nested), do: {:nested, nested}
  defp determine_reason(other_reason), do: other_reason

  @doc """
  Reduces over a nested error. If the error isn't nested the reducer function is only called once.

  Otherwise it will be called for this one and each nested error.
  """
  @spec reduce(t | list(t), accumulator, reducer :: (t, accumulator -> accumulator)) ::
          accumulator
        when accumulator: any
  def reduce(%__MODULE__{} = error, accumulator, reducer) do
    accumulator = reducer.(error, accumulator)

    case error.reason do
      {:nested, errors} ->
        reduce(errors, accumulator, reducer)

      _ ->
        accumulator
    end
  end

  def reduce([%__MODULE__{} | _] = errors, accumulator, reducer) do
    Enum.reduce(errors, accumulator, &reduce(&1, &2, reducer))
  end

  @doc "Returns the errors that actually caused the failure (no nested errors)."
  @spec root_causes(t | list(t)) :: list(t)
  def root_causes(error) do
    error
    |> reduce([], fn
      %{reason: {:nested, _}}, causes -> causes
      %{} = cause, causes -> [cause | causes]
    end)
    |> Enum.reverse()
  end

  @impl true
  def message(%__MODULE__{reason: {:nested, nested}} = error) do
    root_causes = root_causes(nested)

    """
    Failed to transform data in #{context(error)} because of #{length(root_causes)} nested error(s)!

      root cause(s):
        #{stack_trace(root_causes, indent: 4, data: true)}

      stack trace:
        #{stack_trace(nested, indent: 4)}
    """
  end

  def message(%__MODULE__{} = error) do
    """
    Failed to transform data in #{context(error)}!

      data:
        #{data(error, indent: 4)}

      reason:
        #{inspect(error.reason, pretty: true)}
    """
  end

  defp context(%{context: context}) do
    case context do
      %Babel.Step{} -> "Step(#{name(context)})"
      %Babel.Pipeline{} -> "Pipeline(#{name(context)})"
      unknown -> "unknown (#{inspect(unknown)})"
    end
  end

  defp name(%{name: name}) do
    if is_nil(name) do
      "~unnamed~"
    else
      inspect(name)
    end
  end

  defp data(%{data: data}, indent: indent) do
    data
    |> inspect(pretty: true, limit: 80 - indent)
    |> String.split("\n")
    |> Enum.join("\n" <> space(indent))
  end

  defp stack_trace(errors, opts) when is_list(errors) do
    Enum.map_join(
      errors,
      "\n" <> space(opts[:indent] || 0),
      &stack_trace(&1, opts)
    )
  end

  defp stack_trace(%{reason: {:nested, nested}} = error, opts) do
    opts = Keyword.update(opts, :indent, 2, &(&1 + 2))

    "- #{context(error)}\n" <> space(opts[:indent], stack_trace(nested, opts))
  end

  defp stack_trace(%{reason: reason, data: data} = error, opts) do
    indent = opts[:indent] || 0
    reason = inspect(reason, pretty: false, limit: 70 - indent)

    if opts[:data] do
      "- #{context(error)}\n" <>
        space(indent + 2, "| reason: #{reason}\n") <>
        space(indent + 2, "| data: #{inspect(data, pretty: false, limit: 70 - indent)}")
    else
      "- #{context(error)} | reason: #{reason}"
    end
  end

  defp space(indent, string \\ "")
  defp space(0, string), do: string
  defp space(indent, string), do: space(indent - 1, " " <> string)
end
