defmodule Babel.Error do
  defexception [:reason, :data, :step]

  def maybe_wrap_error(maybe_error, params \\ []) do
    case do_wrap(maybe_error) do
      %__MODULE__{} = error ->
        error =
          Enum.reduce(params, error, fn {key, value}, error ->
            Map.put(error, key, value)
          end)

        {:error, error}

      other ->
        other
    end
  end

  defp do_wrap(:error), do: %__MODULE__{reason: :unknown}
  defp do_wrap({:error, %__MODULE__{} = error}), do: error
  defp do_wrap({:error, reason}), do: %__MODULE__{reason: reason}
  defp do_wrap(other), do: other
end
