defprotocol Babel.Intoable do
  @fallback_to_any true

  @typedoc "Any type that implements this protocol."
  @type t :: any

  @type result(output) :: {[Babel.Trace.t()], Babel.Step.result(output)}

  @spec into(t, Babel.Context.t()) :: result(t)
  def into(t, context)
end

defmodule Babel.Intoable.Utils do
  def into_each(enum, context) do
    Babel.Utils.map_nested(enum, &Babel.Intoable.into(&1, context))
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

    {[trace], trace.output}
  end

  defp applicable?(t) do
    not is_nil(Babel.Applicable.impl_for(t))
  end

  defp into_struct(%module{} = struct, context) do
    map = Map.from_struct(struct)

    with {traces, {:ok, map}} <- Babel.Intoable.into(map, context) do
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
  def into(list, context) do
    Babel.Intoable.Utils.into_each(list, context)
  end
end

defimpl Babel.Intoable, for: Tuple do
  # Pattern matching is a lot faster than the Tuple.to_list/1 version below
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
      Enum.concat([t1_traces, t2_traces]),
      case {t1_result, t2_result} do
        {{:ok, t1}, {:ok, t2}} -> {:ok, {t1, t2}}
        {{:error, t1_error}, {:ok, _}} -> {:error, [t1_error]}
        {{:ok, _}, {:error, t2_error}} -> {:error, [t2_error]}
        {{:error, t1_error}, {:error, t2_error}} -> {:error, [t1_error, t2_error]}
      end
    }
  end

  def into({t1, t2, t3}, context) do
    {t1_traces, t1_result} = _into(t1, context)
    {t2_traces, t2_result} = _into(t2, context)
    {t3_traces, t3_result} = _into(t3, context)

    {
      Enum.concat([t1_traces, t2_traces, t3_traces]),
      case {t1_result, t2_result, t3_result} do
        {{:ok, t1}, {:ok, t2}, {:ok, t3}} ->
          {:ok, {t1, t2, t3}}

        {{:error, t1_error}, {:ok, _}, {:ok, _}} ->
          {:error, [t1_error]}

        {{:ok, _}, {:error, t2_error}, {:ok, _}} ->
          {:error, [t2_error]}

        {{:ok, _}, {:ok, _}, {:error, t3_error}} ->
          {:error, [t3_error]}

        {{:error, t1_error}, {:error, t2_error}, {:ok, _}} ->
          {:error, [t1_error, t2_error]}

        {{:error, t1_error}, {:ok, _}, {:error, t3_error}} ->
          {:error, [t1_error, t3_error]}

        {{:ok, _}, {:error, t2_error}, {:error, t3_error}} ->
          {:error, [t2_error, t3_error]}

        {{:error, t1_error}, {:error, t2_error}, {:error, t3_error}} ->
          {:error, [t1_error, t2_error, t3_error]}
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
end
