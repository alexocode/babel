defprotocol Babel.Fetchable do
  @moduledoc false

  @typedoc """
  Anything that implements this protocol.

  Has default implementations for Map, List, and Tuple, and a fallback for structs.
  """
  @type t :: term
  @type implementation :: __MODULE__.Any | __MODULE__.Map | __MODULE__.List | __MODULE__.Tuple

  @fallback_to_any true

  @doc "Fetch the given path from the data"
  @spec fetch(data, path) ::
          {:ok, any}
          | :error
          | {:error, {:not_implemented, __MODULE__, data}}
          | {:error, {:not_supported, implementation, path}}
        when data: any, path: any
  def fetch(data, path)
end

defimpl Babel.Fetchable, for: Any do
  def fetch(%module{} = struct, path) do
    if function_exported?(module, :fetch, 2) do
      Access.fetch(struct, path)
    else
      Map.fetch(struct, path)
    end
  end

  def fetch(other, _path) do
    {:error, {:not_implemented, Babel.Fetchable, other}}
  end
end

defimpl Babel.Fetchable, for: Map do
  defdelegate fetch(map, path), to: Map
end

defimpl Babel.Fetchable, for: List do
  @not_found {__MODULE__, :not_found}

  def fetch(list, index) when is_integer(index) do
    case Enum.at(list, index, @not_found) do
      @not_found -> :error
      found -> {:ok, found}
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

defimpl Babel.Fetchable, for: Range do
  @not_found {__MODULE__, :not_found}

  def fetch(range, index) when is_integer(index) do
    case Enum.at(range, index, @not_found) do
      @not_found -> :error
      found -> {:ok, found}
    end
  end

  def fetch(_range, path) do
    {:error, {:not_supported, __MODULE__, path}}
  end
end

defimpl Babel.Fetchable, for: Tuple do
  def fetch(tuple, pos_index) when is_integer(pos_index) and pos_index >= 0 do
    if tuple_size(tuple) > pos_index do
      {:ok, elem(tuple, pos_index)}
    else
      :error
    end
  end

  def fetch(tuple, neg_index) when is_integer(neg_index) and neg_index < 0 do
    if tuple_size(tuple) >= -neg_index do
      {:ok, Enum.at(Tuple.to_list(tuple), neg_index)}
    else
      :error
    end
  end

  def fetch(_tuple, segment) do
    {:error, {:not_supported, __MODULE__, segment}}
  end
end
