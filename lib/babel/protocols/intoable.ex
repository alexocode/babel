defprotocol Babel.Intoable do
  alias Babel.Context
  alias Babel.Trace

  @fallback_to_any true

  @typedoc "Any type that implements this protocol."
  @type t :: any

  @type result(output) :: {[Trace.t()], {:ok, output} | {:error, reason :: any}}

  @spec into(t, Context.t()) :: result(t)
  def into(t, context)
end

defmodule Babel.Intoable.Utils do
  def into_each(enum, context) do
    Babel.Trace.Nesting.traced_map(enum, &Babel.Intoable.into(&1, context))
  end
end

defimpl Babel.Intoable, for: Any do
  import Kernel, except: [apply: 2]

  require Babel

  # Faster than doing Babel.Applicable.impl_for/1
  def into(%_{} = babel, context) when Babel.is_babel(babel) do
    apply(babel, context)
  end

  def into(%_{} = struct, context) do
    if applicable?(struct) do
      apply(struct, context)
    else
      into_struct(struct, context)
    end
  end

  def into(t, context) do
    if applicable?(t) do
      apply(t, context)
    else
      {[], {:ok, t}}
    end
  end

  defp apply(babel, context) do
    trace = Babel.Applicable.apply(babel, context)

    {[trace], Babel.Trace.result(trace)}
  end

  defp applicable?(t) do
    not is_nil(Babel.Applicable.impl_for(t))
  end

  defp into_struct(%module{} = struct, context) do
    map = Map.from_struct(struct)

    with {traces, {:ok, map}} <- Babel.Intoable.Map.into(map, context) do
      {traces, {:ok, struct(module, map)}}
    end
  end
end

defimpl Babel.Intoable, for: Map do
  def into(map, context) do
    with {traces, {:ok, list}} <- Babel.Intoable.Utils.into_each(map, context) do
      {traces, {:ok, Map.new(list)}}
    end
  end
end

defimpl Babel.Intoable, for: List do
  def into([], _context), do: {[], {:ok, []}}

  def into(list, context) do
    map_and_collect(list, context)
  end

  defp map_and_collect(list, context, traces \\ [], result \\ {:ok, []})

  defp map_and_collect([], _context, traces, {ok_or_error, mapped}) do
    {Enum.reverse(traces), {ok_or_error, Enum.reverse(mapped)}}
  end

  defp map_and_collect([element | rest], context, traces, results) do
    {element_traces, element_result} = Babel.Intoable.into(element, context)

    map_and_collect(
      rest,
      context,
      element_traces ++ traces,
      Babel.Trace.Nesting.collect_results(element_result, results)
    )
  end

  # This handles [1,2,3 | Babel.map(...)]
  defp map_and_collect(improper, context, traces, results)
       when not is_list(improper) do
    {improper_traces, improper_result} = Babel.Intoable.into(improper, context)

    {
      Enum.reduce(traces, improper_traces, &[&1 | &2]),
      case Babel.Trace.Nesting.collect_results(improper_result, results) do
        # There's no guarantee that the improper end evaluates to a proper list;
        # this `Enum.reduce/3` retains a potentially improper list
        {:ok, [mb_improper | mapped]} ->
          {:ok, Enum.reduce(tl(mapped), [hd(mapped) | mb_improper], &[&1 | &2])}

        {:error, reasons} ->
          {:error, Enum.reverse(reasons)}
      end
    }
  end
end

defimpl Babel.Intoable, for: Tuple do
  # Simplest would be to just do `Tuple.to_list/1` but that's comparatively slow;
  # for performance reasons we hand wrote pattern matching versions for up to
  # 4-value tuples (which should cover 99% of cases)

  def into({}, _), do: {[], {:ok, {}}}

  def into({t1}, context) do
    case _into(t1, context) do
      {tr_t1, {:ok, t1}} -> {tr_t1, {:ok, {t1}}}
      other -> other
    end
  end

  def into({t1, t2}, context) do
    {t1_traces, t1_result} = _into(t1, context)
    {t2_traces, t2_result} = _into(t2, context)

    {
      t1_traces ++ t2_traces,
      case {t1_result, t2_result} do
        {{:ok, t1}, {:ok, t2}} ->
          {:ok, {t1, t2}}

        {{:error, t1_error}, {:ok, _}} ->
          {:error, list(t1_error)}

        {{:ok, _}, {:error, t2_error}} ->
          {:error, list(t2_error)}

        {{:error, t1_error}, {:error, t2_error}} ->
          {:error, list(t1_error, t2_error)}
      end
    }
  end

  def into({t1, t2, t3}, context) do
    {t1_traces, t1_result} = _into(t1, context)
    {t2_traces, t2_result} = _into(t2, context)
    {t3_traces, t3_result} = _into(t3, context)

    {
      t1_traces ++ t2_traces ++ t3_traces,
      case {t1_result, t2_result, t3_result} do
        {{:ok, t1}, {:ok, t2}, {:ok, t3}} ->
          {:ok, {t1, t2, t3}}

        {{:error, t1_error}, {:ok, _}, {:ok, _}} ->
          {:error, list(t1_error)}

        {{:ok, _}, {:error, t2_error}, {:ok, _}} ->
          {:error, list(t2_error)}

        {{:ok, _}, {:ok, _}, {:error, t3_error}} ->
          {:error, list(t3_error)}

        {{:error, t1_error}, {:error, t2_error}, {:ok, _}} ->
          {:error, list(t1_error, t2_error)}

        {{:error, t1_error}, {:ok, _}, {:error, t3_error}} ->
          {:error, list(t1_error, t3_error)}

        {{:ok, _}, {:error, t2_error}, {:error, t3_error}} ->
          {:error, list(t2_error, t3_error)}

        {{:error, t1_error}, {:error, t2_error}, {:error, t3_error}} ->
          {:error, list(t1_error, t2_error, t3_error)}
      end
    }
  end

  def into({t1, t2, t3, t4}, context) do
    {t1_traces, t1_result} = _into(t1, context)
    {t2_traces, t2_result} = _into(t2, context)
    {t3_traces, t3_result} = _into(t3, context)
    {t4_traces, t4_result} = _into(t4, context)

    {
      t1_traces ++ t2_traces ++ t3_traces ++ t4_traces,
      case {t1_result, t2_result, t3_result, t4_result} do
        {{:ok, t1}, {:ok, t2}, {:ok, t3}, {:ok, t4}} ->
          {:ok, {t1, t2, t3, t4}}

        {{:error, t1_error}, {:ok, _}, {:ok, _}, {:ok, _}} ->
          {:error, list(t1_error)}

        {{:ok, _}, {:error, t2_error}, {:ok, _}, {:ok, _}} ->
          {:error, list(t2_error)}

        {{:ok, _}, {:ok, _}, {:error, t3_error}, {:ok, _}} ->
          {:error, list(t3_error)}

        {{:ok, _}, {:ok, _}, {:ok, _}, {:error, t4_error}} ->
          {:error, list(t4_error)}

        {{:error, t1_error}, {:error, t2_error}, {:ok, _}, {:ok, _}} ->
          {:error, list(t1_error, t2_error)}

        {{:error, t1_error}, {:ok, _}, {:error, t3_error}, {:ok, _}} ->
          {:error, list(t1_error, t3_error)}

        {{:error, t1_error}, {:ok, _}, {:ok, _}, {:error, t4_error}} ->
          {:error, list(t1_error, t4_error)}

        {{:ok, _}, {:error, t2_error}, {:error, t3_error}, {:ok, _}} ->
          {:error, list(t2_error, t3_error)}

        {{:ok, _}, {:error, t2_error}, {:ok, _}, {:error, t4_error}} ->
          {:error, list(t2_error, t4_error)}

        {{:ok, _}, {:ok, _}, {:error, t3_error}, {:error, t4_error}} ->
          {:error, list(t3_error, t4_error)}

        {{:error, t1_error}, {:error, t2_error}, {:error, t3_error}, {:ok, _}} ->
          {:error, list(t1_error, t2_error, t3_error)}

        {{:error, t1_error}, {:error, t2_error}, {:ok, _}, {:error, t4_error}} ->
          {:error, list(t1_error, t2_error, t4_error)}

        {{:error, t1_error}, {:ok, _}, {:error, t3_error}, {:error, t4_error}} ->
          {:error, list(t1_error, t3_error, t4_error)}

        {{:ok, _}, {:error, t2_error}, {:error, t3_error}, {:error, t4_error}} ->
          {:error, list(t2_error, t3_error, t4_error)}

        {{:error, t1_error}, {:error, t2_error}, {:error, t3_error}, {:error, t4_error}} ->
          {:error, list(t1_error, t2_error, t3_error, t4_error)}
      end
    }
  end

  def into(tuple, context) do
    list = Tuple.to_list(tuple)

    with {traces, {:ok, list}} <- Babel.Intoable.Utils.into_each(list, context) do
      {traces, {:ok, List.to_tuple(list)}}
    end
  end

  defp _into(t, context), do: Babel.Intoable.into(t, context)

  defp list(l1), do: wrap(l1)
  defp list(l1, l2), do: wrap(l1) ++ wrap(l2)
  defp list(l1, l2, l3), do: wrap(l1) ++ wrap(l2) ++ wrap(l3)
  defp list(l1, l2, l3, l4), do: wrap(l1) ++ wrap(l2) ++ wrap(l3) ++ wrap(l4)

  defp wrap(l), do: List.wrap(l)
end
