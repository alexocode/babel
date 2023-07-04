defmodule Babel.Error do
  @type t :: t([t] | any)
  @type t(reason) :: %__MODULE__{
          reason: reason,
          data: Babel.data(),
          step: Babel.Step.t()
        }
  defexception [:reason, :data, :step]

  @spec wrap_if_error(
          {:error, reason} | other,
          Babel.data(),
          Babel.Step.t()
        ) :: {:error, t(reason)} | other
        when reason: any, other: any
  def wrap_if_error(maybe_error, data, step) do
    case do_wrap(maybe_error) do
      %__MODULE__{} = error ->
        {:error, set_if_nil(error, data: data, step: step)}

      other ->
        other
    end
  end

  defp do_wrap(:error), do: %__MODULE__{reason: :unknown}
  defp do_wrap({:error, %__MODULE__{} = error}), do: error
  defp do_wrap({:error, [%__MODULE__{} = error]}), do: error
  defp do_wrap({:error, reason}), do: %__MODULE__{reason: reason}
  defp do_wrap(other), do: other

  defp set_if_nil(error, params) do
    Enum.reduce(params, error, fn {key, value}, error ->
      Map.update!(error, key, fn
        nil -> value
        existing -> existing
      end)
    end)
  end

  @impl true
  def message(%__MODULE__{} = error) do
    """
    Failed to transform data at step #{step_name(error)}!

      data:
        #{data(error, indent: "    ")}

      reason:
        #{reason(error, indent: "    ")}
    """
  end

  defp step_name(%{step: step}) do
    if is_nil(step.name) do
      "(unnamed)"
    else
      "#{inspect(step.name)}"
    end
  end

  defp data(%{data: data}, indent: indent) do
    data
    |> inspect(pretty: true, limit: 50)
    |> String.split("\n")
    |> Enum.join("\n" <> indent)
  end

  defp reason(%{reason: [%__MODULE__{} = nested | _] = list} = error, indent: indent) do
    "#{deep_length(list)} nested errors (e.g. #{short_explain(nested)})" <>
      "\n" <> long_explain(error, indent: indent)
  end

  defp reason(%{reason: reason}, indent: indent) do
    indent <> inspect(reason, pretty: true, limit: :infinity)
  end

  defp deep_length(list) do
    Enum.reduce(list, 0, fn
      list, count when is_list(list) ->
        count + deep_length(list)

      _, count ->
        count + 1
    end)
  end

  defp short_explain(%{reason: [%__MODULE__{} = nested | _]}), do: short_explain(nested)
  defp short_explain(%{reason: reason}), do: inspect(reason, pretty: false, limit: 30)

  defp long_explain(%{reason: [%__MODULE__{} | _] = list} = error, indent: indent) do
    nested_explanations =
      list
      |> Enum.flat_map(fn error ->
        error
        |> long_explain(indent: indent <> "  ")
        |> List.wrap()
      end)
      |> Enum.join("\n")

    indent <> "- Step(#{step_name(error)}) |\n" <> nested_explanations
  end

  defp long_explain(%{} = error, indent: indent) do
    step_name = if error.step.name, do: inspect(error.step.name), else: "unnamed"

    indent <> "- Step(#{step_name}) | reason: #{inspect(error.reason, pretty: false, limit: 50)}"
  end
end
