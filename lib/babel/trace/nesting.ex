defmodule Babel.Trace.Nesting do
  @moduledoc false

  alias Babel.Trace

  @type traces_with_result(output) :: {[Trace.t()], result(output)}
  @type result(output) :: {:ok, output} | {:error, reason :: any}

  @spec traced_map(
          enum :: Enumerable.t(input),
          mapper :: (input -> Trace.t(output) | traces_with_result(output))
        ) :: {[Trace.t()], {:ok, [output]} | {:error, [reason :: any]}}
        when input: any, output: any
  def traced_map(enum, mapper) when is_function(mapper, 1) do
    {traces, {ok_or_error, list}} =
      traced_reduce(enum, mapper, {:ok, []}, fn result, accumulated ->
        {:cont, collect_results(result, accumulated)}
      end)

    {traces, {ok_or_error, Enum.reverse(list)}}
  end

  @spec traced_reduce(
          enum :: Enumerable.t(input),
          mapper :: (input -> Trace.t(output) | traces_with_result(output)),
          begin :: accumulated,
          accumulator :: (result(output), accumulated -> {:cont | :halt, accumulated})
        ) :: {[Trace.t()], accumulated}
        when input: any, output: any, accumulated: any
  def traced_reduce(enum, mapper, begin, accumulator)
      when is_function(mapper, 1)
      when is_function(accumulator, 2) do
    {traces, accumulated} =
      Enum.reduce_while(enum, {[], begin}, fn element, {traces, accumulated} ->
        {nested_traces, result} =
          case mapper.(element) do
            %Trace{} = trace -> {[trace], Trace.result(trace)}
            {traces, result} -> {traces, result}
          end

        {cont_or_halt, accumulated} = accumulator.(result, accumulated)

        {cont_or_halt, {Enum.reverse(nested_traces) ++ traces, accumulated}}
      end)

    {Enum.reverse(traces), accumulated}
  end

  @doc "Combines `collect_oks/2` and `collect_errors/2`. When `collect_oks/2` returns `nil` it calls `collect_errors/2`."
  @spec collect_results(result(any), result([any])) :: result([any])
  def collect_results(result, collected) do
    collect_oks(result, collected) || collect_errors(result, collected)
  end

  @doc """
  Aggregates `:ok` results. Returns `nil` for `:error` results.

  ## Examples

      iex> collect_oks({:ok, :some_value}, {:ok, []})
      {:ok, [:some_value]}

      iex> collect_oks({:ok, :another_value}, {:ok, [:some_value]})
      {:ok, [:another_value, :some_value]}

      iex> collect_oks({:error, :some_reason}, {:ok, [:some_value, :another_value]})
      nil

      iex> collect_oks({:ok, :some_value}, {:error, [:some_reason]})
      nil
  """
  @spec collect_oks({:ok, value}, {:ok, [value]}) :: {:ok, [value]} when value: any
  def collect_oks(result, {:ok, l}) do
    case result do
      {:ok, value} -> {:ok, [value | l]}
      {:error, _} -> nil
    end
  end

  @spec collect_oks({:error, reason :: any}, {:ok, list}) :: nil
  def collect_oks(_result, {:error, _}), do: nil

  @doc """
  Aggregates `:error` results. Ignores `:ok` results.

  ## Examples

      iex> collect_errors({:error, :some_reason}, {:ok, [:some_value, :another_value]})
      {:error, [:some_reason]}

      iex> collect_errors({:error, :another_reason}, {:error, [:some_reason]})
      {:error, [:another_reason, :some_reason]}

      iex> collect_errors({:error, [:further_reason, :another_reason]}, {:error, [:some_reason]})
      {:error, [:another_reason, :further_reason, :some_reason]}

      iex> collect_errors({:ok, :another_value}, {:ok, [:some_value]})
      nil
  """
  @spec collect_errors({:ok, any}, {:ok, any}) :: nil
  @spec collect_errors({:error, reason}, {:ok, any}) :: {:error, [reason]} when reason: any
  def collect_errors(result, {:ok, _}) do
    case result do
      {:ok, _} -> nil
      {:error, reason} -> {:error, List.wrap(reason)}
    end
  end

  @spec collect_errors({:ok, any}, {:error, [reason]}) :: {:error, [reason]} when reason: any
  @spec collect_errors({:error, [reason]}, {:error, [reason]}) :: {:error, [reason]}
        when reason: any
  def collect_errors(result, {:error, list}) do
    case result do
      {:ok, _} -> {:error, list}
      {:error, reasons} when is_list(reasons) -> {:error, Enum.reverse(reasons) ++ list}
      {:error, reason} -> {:error, [reason | list]}
    end
  end

  defmacro traced_try(babel, input, do: block) do
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
