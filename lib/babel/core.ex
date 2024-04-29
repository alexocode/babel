defmodule Babel.Core do
  @moduledoc false

  alias __MODULE__.Primitives
  alias Babel.Step
  alias Babel.Trace

  require Step

  @type data :: Babel.data()
  @type path :: term | list(term)

  @core_names ~w[id const fetch get cast into call then choice map flat_map]a
  @doc "Determines whether or not the step is a known core step."
  @spec is_core(any) :: boolean
  defguard is_core(step)
           when is_struct(step, Babel.Step) and
                  is_tuple(step.name) and tuple_size(step.name) == 2 and
                  elem(step.name, 0) in @core_names

  @doc "Determines whether or not the step is a known core step."
  @spec core?(any) :: boolean
  def core?(thing), do: is_core(thing)

  @spec id() :: Step.t(input, input) when input: any
  def id do
    Step.new({:id, []}, &Function.identity/1)
  end

  @spec const(value) :: Step.t(value) when value: any
  def const(value) do
    Step.new({:const, [value]}, fn _ -> value end)
  end

  @spec fetch(path) :: Step.t(data)
  def fetch(path) do
    path_as_list = List.wrap(path)

    Step.new({:fetch, [path]}, &Primitives.fetch(&1, path_as_list))
  end

  @spec get(path, default) :: Step.t(data, any | default) when default: any
  def get(path, default) do
    path_as_list = List.wrap(path)

    Step.new({:get, [path, default]}, &Primitives.get(&1, path_as_list, default))
  end

  @spec cast(:integer) :: Step.t(data, integer)
  @spec cast(:float) :: Step.t(data, float)
  @spec cast(:boolean) :: Step.t(data, boolean)
  def cast(type) when type in [:boolean, :float, :integer] do
    Step.new({:cast, [type]}, &Primitives.cast(type, &1))
  end

  @spec into(intoable) :: Step.t(data, intoable) when intoable: Babel.Intoable.t()
  def into(intoable) do
    Step.new({:into, [intoable]}, &Babel.Intoable.into(intoable, &1))
  end

  @spec call(module, function_name :: atom, extra_args :: list) :: Step.t()
  def call(module, function_name, extra_args \\ [])
      when is_atom(module) and is_atom(function_name) and is_list(extra_args) do
    unless function_exported?(module, function_name, 1 + length(extra_args)) do
      raise ArgumentError,
            "cannot call missing function `#{inspect(module)}.#{function_name}/#{1 + length(extra_args)}`"
    end

    Step.new(
      {:call, [module, function_name, extra_args]},
      &Kernel.apply(module, function_name, [&1 | extra_args])
    )
  end

  @spec then(custom_name :: nil | any, function :: Step.fun(input, output)) ::
          Step.t(input, output)
        when input: any, output: any
  def then(custom_name \\ nil, function) do
    full_name = Enum.reject([custom_name, function], &is_nil/1)

    Step.new({:then, full_name}, function)
  end

  @spec choice(chooser :: (input -> Babel.applicable(input, output))) :: Step.t(input, output)
        when input: data, output: any
  def choice(chooser) when is_function(chooser, 1) do
    Step.new({:choice, [chooser]}, fn input ->
      trace = Trace.apply(chooser.(input), input)

      {[trace], trace.result}
    end)
  end

  @spec map(mapper :: Babel.applicable(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: data, output: any
  def map(mapper) do
    do_flat_map({:map, [mapper]}, fn _ -> mapper end)
  end

  @spec flat_map(mapper :: (input -> Babel.applicable(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def flat_map(mapper) when is_function(mapper, 1) do
    do_flat_map({:flat_map, [mapper]}, mapper)
  end

  defp do_flat_map(name, mapper) do
    Step.new(
      name,
      &Babel.Utils.map_and_collapse_to_result(&1, fn element ->
        Babel.Trace.apply(mapper.(element), element)
      end)
    )
  end
end
