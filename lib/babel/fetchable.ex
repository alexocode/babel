defprotocol Babel.Fetchable do
  @fallback_to_any true

  @doc "Fetch the given path the data"
  @spec fetch(data :: any, path :: any) :: {:ok, any} | :error | {:error, reason :: any}
  def fetch(data, path)
end

defimpl Babel.Fetchable, for: Any do
  def fetch(%_{} = struct, path) do
    Map.fetch(struct, path)
  end
end

defimpl Babel.Fetchable, for: Map do
  def fetch(map, path) do
    Map.fetch(map, path)
  end
end

defimpl Babel.Fetchable, for: List do
  def fetch(list, index) when is_integer(index) do
    list
    |> Enum.reduce_while(0, fn element, count ->
      if count == index do
        {:halt, {:ok, element}}
      else
        {:cont, count + 1}
      end
    end)
    |> case do
      {:ok, value} ->
        {:ok, value}

      _ ->
        :error
    end
  end

  def fetch(list, path) do
    case List.keyfind(list, path, 0, nil) do
      {^path, value} ->
        {:ok, value}

      nil ->
        :error
    end
  end
end

defimpl Babel.Fetchable, for: Tuple do
  def fetch(tuple, index) when is_integer(index) and tuple_size(tuple) > index do
    {:ok, elem(tuple, index)}
  end

  def fetch(_tuple, _path) do
    :error
  end
end
