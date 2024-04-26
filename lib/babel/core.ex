defmodule Babel.Core do
  @moduledoc false

  alias __MODULE__.Primitives
  alias Babel.Step

  require Step

  @type data :: Babel.data()
  @type path :: term | list(term)

  @spec id() :: Step.t(input, input) when input: any
  def id do
    Step.new(:id, & &1)
  end

  @spec const(value) :: Step.t(value) when value: any
  def const(value) do
    Step.new({:const, value}, fn _ -> value end)
  end

  @spec fetch(path) :: Step.t(data)
  def fetch(path) do
    path = List.wrap(path)

    Step.new({:fetch, path}, &Primitives.fetch(&1, path))
  end

  @spec get(path, default) :: Step.t(data, any | default) when default: any
  def get(path, default) do
    path = List.wrap(path)

    Step.new({:get, path, default}, &Primitives.get(&1, path, default))
  end

  @spec cast(:integer) :: Step.t(data, integer)
  @spec cast(:float) :: Step.t(data, float)
  @spec cast(:boolean) :: Step.t(data, boolean)
  def cast(type) when type in [:boolean, :float, :integer] do
    Step.new({:cast, type}, &Primitives.cast(type, &1))
  end

  @spec into(intoable) :: Step.t(data, intoable) when intoable: Babel.Intoable.t()
  def into(intoable)

  def into(intoable) do
    type =
      case intoable do
        %struct{} -> struct
        %{} -> :map
        list when is_list(list) -> :list
        tuple when is_tuple(tuple) -> :tuple
        other -> other
      end

    Step.new({:into, type}, &Babel.Intoable.into(intoable, &1))
  end

  @spec choice(chooser :: (input -> Babel.applicable(input, output))) :: Step.t(input, output)
        when input: data, output: any
  def choice(chooser) when is_function(chooser, 1) do
    Step.new(:choice, fn input ->
      input
      |> chooser.()
      |> Babel.Applicable.apply(input)
    end)
  end

  @spec map(mapper :: Babel.applicable(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: data, output: any
  def map(mapper) do
    do_flat_map(:map, fn _ -> mapper end)
  end

  @spec flat_map(mapper :: (input -> Babel.applicable(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def flat_map(mapper) when is_function(mapper, 1) do
    do_flat_map(:flat_map, mapper)
  end

  defp do_flat_map(name, mapper) do
    Step.new(
      name,
      &__MODULE__.Helper.map_and_collapse_results(&1, fn element ->
        Babel.Applicable.apply(mapper.(element), element)
      end)
    )
  end

  # TODO: Add docs
  @spec wrap(module, function_name :: atom, args :: list) :: Step.t()
  def wrap(module, function_name, args)
      when is_atom(module) and is_atom(function_name) and is_list(args) do
    unless function_exported?(module, function_name, 1 + length(args)) do
      raise ArgumentError,
            "Invalid function spec: `#{inspect(module)}.#{function_name}/#{1 + length(args)}` doesn't seem to exist"
    end

    Step.new({module, function_name}, &Kernel.apply(module, function_name, [&1 | args]))
  end
end
