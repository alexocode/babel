defmodule Babel.Utils do
  @moduledoc false

  @type traces_with_result(output) :: {[Babel.Trace.t()], {:ok, output} | {:error, reason :: any}}

  @spec map_nested(
          enum :: Enumerable.t(input),
          mapper :: (input -> Babel.Trace.t(output) | traces_with_result(output))
        ) :: {[Babel.Trace.t()], {:ok, [output]} | {:error, [reason :: any]}}
        when input: any, output: any
  def map_nested(enum, mapper) when is_function(mapper, 1) do
    {traces, {ok_or_error, list}} =
      Enum.reduce(enum, {[], {:ok, []}}, fn element, {traces, {ok_or_error, list}} ->
        {nested_traces, result} =
          case mapper.(element) do
            %Babel.Trace{} = trace -> {[trace], Babel.Trace.result(trace)}
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

  defmacro trace_try(babel, input, do: block) do
    quote do
      trace_or_result =
        try do
          unquote(block)
        rescue
          error in [Babel.Error] -> error.trace
          other -> {:error, other}
        else
          %Babel.Trace{} = trace ->
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

      case trace_or_result do
        %Babel.Trace{} = trace ->
          Babel.Trace.new(unquote(babel), unquote(input), trace.output, [trace])

        result ->
          Babel.Trace.new(unquote(babel), unquote(input), result)
      end
    end
  end
end
