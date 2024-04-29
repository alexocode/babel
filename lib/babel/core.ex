defmodule Babel.Core do
  @moduledoc false

  alias Babel.Step
  alias Babel.Trace
  alias Babel.Utils

  require Step

  @type data :: Babel.data()
  @type path :: term | list(term)

  @core_names ~w[id const fetch get cast into call choice map flat_map fail try then]a
  @doc "Determines whether or not the step is a known core step."
  @spec is_core(any) :: boolean
  defguard is_core(step)
           when is_struct(step, Step) and
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

    Step.new({:fetch, [path]}, &__MODULE__.Fetch.call(&1, path_as_list))
  end

  @spec get(path, default) :: Step.t(data, any | default) when default: any
  def get(path, default \\ nil) do
    path_as_list = List.wrap(path)

    Step.new({:get, [path, default]}, &__MODULE__.Get.call(&1, path_as_list, default))
  end

  @spec cast(:integer) :: Step.t(data, integer)
  @spec cast(:float) :: Step.t(data, float)
  @spec cast(:boolean) :: Step.t(data, boolean)
  def cast(type) when type in [:boolean, :float, :integer] do
    Step.new({:cast, [type]}, &__MODULE__.Cast.call(type, &1))
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

  @spec choice(chooser :: (input -> Babel.t(input, output))) :: Step.t(input, output)
        when input: data, output: any
  def choice(chooser) when is_function(chooser, 1) do
    Step.new({:choice, [chooser]}, fn input ->
      trace = Trace.apply(chooser.(input), input)

      {[trace], trace.result}
    end)
  end

  @spec map(mapper :: Babel.t(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: data, output: any
  def map(mapper) do
    do_flat_map({:map, [mapper]}, fn _ -> mapper end)
  end

  @spec flat_map(mapper :: (input -> Babel.t(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def flat_map(mapper) when is_function(mapper, 1) do
    do_flat_map({:flat_map, [mapper]}, mapper)
  end

  defp do_flat_map(name, mapper) do
    Step.new(
      name,
      &Utils.map_and_collapse_to_result(&1, fn element ->
        Trace.apply(mapper.(element), element)
      end)
    )
  end

  @spec fail(reason_function :: (input -> reason)) :: Step.t(no_return)
        when input: any, reason: any
  def fail(reason_function) when is_function(reason_function, 1) do
    Step.new({:fail, [reason_function]}, &{:error, reason_function.(&1)})
  end

  @spec fail(reason :: any) :: Step.t(no_return)
  def fail(reason) do
    Step.new({:fail, [reason]}, fn _ -> {:error, reason} end)
  end

  @spec try(Babel.t(output) | [Babel.t(output)]) :: Step.t(output)
        when output: any
  def try(applicables) do
    name = {:try, [applicables]}
    applicables = List.wrap(applicables)

    Step.new(name, &__MODULE__.Try.call(applicables, &1))
  end

  @spec try(Babel.t(output) | [Babel.t(output)], default) :: Step.t(output | default)
        when output: any, default: any
  def try(applicables, default) do
    name = {:try, [applicables, default]}
    applicables = List.wrap(applicables) ++ [const(default)]

    Step.new(name, &__MODULE__.Try.call(applicables, &1))
  end

  @spec then(custom_name :: nil | any, function :: Step.fun(input, output)) ::
          Step.t(input, output)
        when input: any, output: any
  def then(custom_name \\ nil, function) do
    full_name = Enum.reject([custom_name, function], &is_nil/1)

    Step.new({:then, full_name}, function)
  end
end
