defmodule Babel.Helper do
  @moduledoc false

  @spec map_and_collapse_results(
          Babel.data(),
          mapper :: (any -> {:ok, output} | {:error, error})
        ) :: {:ok, [output]} | {:error, [error]}
        when output: term, error: Babel.Error.t()
  def map_and_collapse_results(data, mapper) when is_function(mapper, 1) do
    {ok_or_error, list} =
      Enum.reduce(data, {:ok, []}, fn element, {ok_or_error, list} ->
        case {ok_or_error, mapper.(element)} do
          {:ok, {:ok, value}} ->
            {:ok, [value | list]}

          {:ok, {:error, error}} ->
            {:error, List.wrap(error)}

          {:error, {:ok, _}} ->
            {:error, list}

          {:error, {:error, errors}} when is_list(errors) ->
            {:error, Enum.reverse(errors) ++ list}

          {:error, {:error, error}} ->
            {:error, [error | list]}
        end
      end)

    {ok_or_error, Enum.reverse(list)}
  end
end
