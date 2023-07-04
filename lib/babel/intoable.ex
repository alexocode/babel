defprotocol Babel.Intoable do
  @fallback_to_any true

  @type t :: any

  @spec into(t, Babel.data()) :: Babel.Step.result(t)
  def into(t, data)
end

defmodule Babel.Intoable.Helper do
  def into_each(enum, data) do
    Babel.Helper.map_and_collapse_results(enum, &Babel.Intoable.into(&1, data))
  end
end

defimpl Babel.Intoable, for: Any do
  def into(%Babel.Pipeline{} = pipeline, data) do
    Babel.Pipeline.apply(pipeline, data)
  end

  def into(%Babel.Step{} = step, data) do
    Babel.Step.apply(step, data)
  end

  def into(%_{} = struct, data) do
    if is_applicable(struct) do
      Babel.Applicable.apply(struct, data)
    else
      into_struct(struct, data)
    end
  end

  def into(t, data) do
    if is_applicable(t) do
      Babel.Applicable.apply(t, data)
    else
      {:ok, t}
    end
  end

  defp is_applicable(t) do
    not is_nil(Babel.Applicable.impl_for(t))
  end

  defp into_struct(%module{} = struct, data) do
    map = Map.from_struct(struct)

    with {:ok, map} <- Babel.Intoable.into(map, data) do
      {:ok, struct(module, map)}
    end
  end
end

defimpl Babel.Intoable, for: Map do
  def into(map, data) do
    with {:ok, list} <- Babel.Intoable.Helper.into_each(map, data) do
      {:ok, Map.new(list)}
    end
  end
end

defimpl Babel.Intoable, for: List do
  def into(list, data) do
    Babel.Intoable.Helper.into_each(list, data)
  end
end

defimpl Babel.Intoable, for: Tuple do
  # Pattern matching is a lot faster than the Tuple.to_list/1 version below
  def into({}, _), do: {:ok, {}}

  def into({t1}, data) do
    case _into(t1, data) do
      {:ok, t1} -> {:ok, {t1}}
      other -> other
    end
  end

  def into({t1, t2}, data) do
    t1_result = _into(t1, data)
    t2_result = _into(t2, data)

    case {t1_result, t2_result} do
      {{:ok, t1}, {:ok, t2}} -> {:ok, {t1, t2}}
      {{:error, t1_error}, {:ok, _}} -> {:error, [t1_error]}
      {{:ok, _}, {:error, t2_error}} -> {:error, [t2_error]}
      {{:error, t1_error}, {:error, t2_error}} -> {:error, [t1_error, t2_error]}
    end
  end

  def into({t1, t2, t3}, data) do
    t1_result = _into(t1, data)
    t2_result = _into(t2, data)
    t3_result = _into(t3, data)

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
  end

  def into(tuple, data) do
    list = Tuple.to_list(tuple)

    with {:ok, list} <- Babel.Intoable.Helper.into_each(list, data) do
      {:ok, List.to_tuple(list)}
    end
  end

  defp _into(t, data), do: Babel.Intoable.into(t, data)
end
