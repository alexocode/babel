defmodule Babel.Utils do
  @moduledoc false

  alias Babel.Trace

  @spec resultify(:error) :: {:error, :unknown}
  def resultify(:error), do: {:error, :unknown}
  @spec resultify({:error, reason}) :: {:error, reason} when reason: any
  def resultify({:error, reason}), do: {:error, reason}
  @spec resultify({:ok, value}) :: {:ok, value} when value: any
  def resultify({:ok, value}), do: {:ok, value}
  @spec resultify(value) :: {:ok, value} when value: any
  def resultify(value), do: {:ok, value}

  @spec map_and_collapse_to_result(Babel.data(), mapper :: (any -> Trace.t(output))) ::
          Babel.Applicable.result([output])
        when output: term
  def map_and_collapse_to_result(data, mapper) when is_function(mapper, 1) do
    {traces, {ok_or_error, list}} =
      Enum.reduce(data, {[], {:ok, []}}, fn element, {traces, {ok_or_error, list}} ->
        {nested_traces, result} =
          element
          |> mapper.()
          |> traces_and_result()

        {
          Enum.reverse(nested_traces) ++ traces,
          collapse_to_result(list, ok_or_error, result)
        }
      end)

    {Enum.reverse(traces), {ok_or_error, Enum.reverse(list)}}
  end

  defp traces_and_result(%Trace{} = trace), do: {[trace], trace.result}
  defp traces_and_result({traces, result}), do: {traces, result}

  defp collapse_to_result(list, :ok, result) do
    case result do
      {:ok, value} ->
        {:ok, [value | list]}

      {:error, error} ->
        {:error, List.wrap(error)}
    end
  end

  defp collapse_to_result(list, :error, result) do
    case result do
      {:ok, _} ->
        {:error, list}

      {:error, errors} when is_list(errors) ->
        {:error, Enum.reverse(errors) ++ list}

      {:error, error} ->
        {:error, [error | list]}
    end
  end
end
