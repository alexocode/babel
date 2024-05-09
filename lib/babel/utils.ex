defmodule Babel.Utils do
  @moduledoc false

  alias Babel.Context
  alias Babel.Step
  alias Babel.Trace

  @spec map_nested(
          enum :: Enumerable.t(element),
          mapper :: (Context.t(element) -> Step.result(output) | Trace.t(output))
        ) :: {[Trace.t()], {:ok, [output]} | {:error, [reason :: any]}}
        when element: any, output: any
  def map_nested(enum, mapper) when is_function(mapper, 1) do
    {traces, {ok_or_error, list}} =
      Enum.reduce(enum, {[], {:ok, []}}, fn element, {traces, {ok_or_error, list}} ->
        {nested_traces, result} =
          case mapper.(element) do
            %Trace{} = trace -> {[trace], trace.output}
            {traces, result} -> {traces, result}
          end

        {
          Enum.reverse(nested_traces) ++ traces,
          accumulate_result(list, ok_or_error, result)
        }
      end)

    {Enum.reverse(traces), {ok_or_error, Enum.reverse(list)}}
  end

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

  @spec safe_apply(
          function :: (any -> Step.result(output) | Trace.t(output)),
          data :: Babel.data()
        ) :: Trace.t(output) | Trace.result(output)
        when output: any
  def safe_apply(function, data) do
    case function.(data) do
      %Trace{} = trace ->
        trace

      # People might do a `Babel.apply/2` inside of the given function;
      # this ensures trace information gets retained in these cases
      %Babel.Error{trace: trace} ->
        trace

      {:error, %Babel.Error{trace: trace}} ->
        trace

      result ->
        result
    end
  rescue
    error in [Babel.Error] -> error.trace
    other -> {:error, other}
  end
end
