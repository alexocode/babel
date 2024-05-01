defmodule Babel.Utils do
  @moduledoc false

  @type result_or_trace(output) :: Babel.Applicable.result(output) | Babel.Trace.t(output)

  @spec collapse_to_result(
          result :: result_or_trace(output),
          accumulated :: Babel.Applicable.result([output])
        ) :: Babel.Applicable.result([output])
        when output: any
  def collapse_to_result(result, {traces, {ok_or_error, list}}) do
    {nested_traces, result} = traces_and_result(result)

    {
      Enum.reverse(nested_traces) ++ traces,
      accumulate_result(list, ok_or_error, result)
    }
  end

  defp traces_and_result(%Babel.Trace{} = trace), do: {[trace], trace.result}
  defp traces_and_result({traces, result}), do: {traces, result}

  defp accumulate_result(list, :ok, result) do
    case result do
      {:ok, value} ->
        {:ok, [value | list]}

      {:error, error} ->
        {:error, List.wrap(error)}
    end
  end

  defp accumulate_result(list, :error, result) do
    case result do
      {:ok, _} ->
        {:error, list}

      {:error, errors} when is_list(errors) ->
        {:error, Enum.reverse(errors) ++ list}

      {:error, error} ->
        {:error, [error | list]}
    end
  end

  @spec map_and_collapse_to_result(
          data :: Enum.t(),
          mapper :: (any -> result_or_trace(output))
        ) :: Babel.Applicable.result([output])
        when output: any
  def map_and_collapse_to_result(data, mapper) when is_function(mapper, 1) do
    {traces, {ok_or_error, list}} =
      Enum.reduce(data, {[], {:ok, []}}, fn element, accumulated_result ->
        element
        |> mapper.()
        |> collapse_to_result(accumulated_result)
      end)

    {Enum.reverse(traces), {ok_or_error, Enum.reverse(list)}}
  end

  @spec safe_apply(function :: Babel.Step.fun(output), data :: Babel.data()) ::
          Babel.Applicable.result(output)
        when output: any
  def safe_apply(function, data) do
    case function.(data) do
      {traces, result} when is_list(traces) ->
        {traces, resultify(result)}

      # People might do a `Babel.apply/2` inside of the given function;
      # this ensures trace information gets retained in these cases
      {:error, %Babel.Error{trace: trace}} ->
        {[trace], trace.result}

      result ->
        {[], resultify(result)}
    end
  rescue
    error in [Babel.Error] -> {[error.trace], error.trace.result}
    other -> {[], {:error, other}}
  end

  @spec resultify(:error) :: {:error, :unknown}
  def resultify(:error), do: {:error, :unknown}
  @spec resultify({:error, reason}) :: {:error, reason} when reason: any
  def resultify({:error, reason}), do: {:error, reason}
  @spec resultify({:ok, value}) :: {:ok, value} when value: any
  def resultify({:ok, value}), do: {:ok, value}
  @spec resultify(value) :: {:ok, value} when value: any
  def resultify(value), do: {:ok, value}
end
