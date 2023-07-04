defmodule Babel.Step.Builder do
  @moduledoc false

  alias Babel.Step
  alias Babel.Step.Builder.Primitives

  require Step

  @type path :: term | list(term)
  @type name :: Step.name()

  @spec fetch(name, path) :: Step.t(Babel.data())
  def fetch(name \\ nil, path) do
    path = List.wrap(path)

    Step.new(name || {:fetch, path}, &Primitives.fetch(&1, path))
  end

  @spec get(name, path, default) :: Step.t(Babel.data(), any | default) when default: any
  def get(name \\ nil, path, default) do
    path = List.wrap(path)

    Step.new(name || {:get, path}, &Primitives.get(&1, path, default))
  end

  @spec cast(:integer) :: Step.t(Babel.data(), integer)
  @spec cast(:float) :: Step.t(Babel.data(), float)
  @spec cast(:boolean) :: Step.t(Babel.data(), boolean)
  @spec cast(Step.step_fun(input, output)) :: Step.t(input, output) when input: any, output: any
  @spec cast(name, :integer) :: Step.t(Babel.data(), integer)
  @spec cast(name, :float) :: Step.t(Babel.data(), float)
  @spec cast(name, :boolean) :: Step.t(Babel.data(), boolean)
  @spec cast(name, Step.step_fun(input, output)) :: Step.t(input, output)
        when input: any, output: any
  def cast(name \\ nil, type_or_function)

  def cast(name, type) when type in [:boolean, :float, :integer] do
    cast(name || {:cast, type}, &Primitives.cast(type, &1))
  end

  def cast(name, function) when is_function(function, 1) do
    Step.new(name || :cast, function)
  end

  @spec into(intoable) :: Step.t(any, intoable) when intoable: Babel.Intoable.t()
  @spec into(name, intoable) :: Step.t(any, intoable) when intoable: Babel.Intoable.t()
  def into(name \\ nil, intoable)

  def into(name, intoable) do
    type =
      case intoable do
        %struct{} -> struct
        %{} -> :map
        list when is_list(list) -> :list
        tuple when is_tuple(tuple) -> :tuple
        other -> other
      end

    Step.new(name || {:into, type}, &Babel.Intoable.into(intoable, &1))
  end

  @spec map(mapper :: Babel.applicable(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  @spec map(name, mapper :: Babel.applicable(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def map(name \\ nil, mapper) do
    flat_map(name || :map, fn _ -> mapper end)
  end

  @spec flat_map(mapper :: (input -> Babel.applicable(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  @spec flat_map(name, mapper :: (input -> Babel.applicable(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def flat_map(name \\ nil, mapper)

  def flat_map(name, mapper) when is_function(mapper, 1) do
    name = name || :flat_map

    Step.new(
      name,
      &Babel.Helper.map_and_collapse_results(&1, fn element ->
        Babel.apply(mapper.(element), element)
      end)
    )
  end
end
