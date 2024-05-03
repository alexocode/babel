defmodule Babel.Builtin do
  @moduledoc false

  alias Babel.Step
  alias Babel.Trace
  alias Babel.Utils

  require Step

  @builtin_names ~w[
    call
    cast
    choice
    const
    fail
    fetch
    flat_map
    get
    identity
    into
    map
    then
    try
  ]a

  @type name :: unquote(Enum.reduce(@builtin_names, &{:|, [], [&1, &2]}))
  @type name_with_args :: {name, [arg :: term]}

  @type data :: Babel.data()
  @type path :: term | list(term)

  @doc """
  Determines whether or not the given name is the name of a known core step.

  Accepts both the name atom (`t:name`) or the full name tuple with arguments (`t:name_with_arguments`).

  ## Examples

  #{Enum.map_join(@builtin_names, &"""
      iex> Babel.Builtin.is_builtin_name(#{inspect(&1)})
      true

  """)}

      # The second argument NEEDS to be a list of arguments
      iex> Babel.Builtin.is_builtin_name({:fetch, "foo"})
      false

      iex> Babel.Builtin.is_builtin_name({:fetch, [["foo", "bar"]]})
      true

      iex> Babel.Builtin.is_builtin_name(:not_a_core_step)
      false
  """
  @spec is_builtin_name(atom | tuple | any) :: boolean
  defguard is_builtin_name(name)
           when (is_atom(name) and name in @builtin_names) or
                  (is_tuple(name) and tuple_size(name) == 2 and elem(name, 0) in @builtin_names and
                     is_list(elem(name, 1)))

  @doc """
  Determines whether or not the given step is a known core step.

  ## Examples

      iex> Babel.Builtin.is_builtin_step(Babel.Builtin.identity())
      true

      iex> Babel.Builtin.is_builtin_step(Babel.Builtin.then(:custom_name, fn _ -> :do_stuff end))
      true

      iex> Babel.Builtin.is_builtin_step(Babel.Step.new(:some_weird_name, fn _ -> :do_stuff end))
      false
  """
  @spec is_builtin_step(Step.t() | any) :: boolean
  defguard is_builtin_step(step) when is_struct(step, Step) and is_builtin_name(step.name)

  @doc "Determines whether or not the step is a known core step."
  @spec builtin?(any) :: boolean
  def builtin?(thing), do: is_builtin_step(thing)

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

  @spec cast(:integer) :: Step.t(data, integer)
  @spec cast(:float) :: Step.t(data, float)
  @spec cast(:boolean) :: Step.t(data, boolean)
  def cast(type) when type in [:boolean, :float, :integer] do
    Step.new({:cast, [type]}, &__MODULE__.Cast.call(type, &1))
  end

  @spec choice(chooser :: (input -> Babel.t(input, output))) :: Step.t(input, output)
        when input: data, output: any
  def choice(chooser) when is_function(chooser, 1) do
    Step.new({:choice, [chooser]}, fn input ->
      trace = Trace.apply(chooser.(input), input)

      {[trace], trace.output}
    end)
  end

  @spec const(value) :: Step.t(value) when value: any
  def const(value) do
    Step.new({:const, [value]}, fn _ -> value end)
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

  @spec fetch(path) :: Step.t(data)
  def fetch(path) do
    path_as_list = List.wrap(path)

    Step.new({:fetch, [path]}, &__MODULE__.Fetch.call(&1, path_as_list))
  end

  @spec flat_map(mapper :: (input -> Babel.t(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def flat_map(mapper) when is_function(mapper, 1) do
    Step.new(
      {:flat_map, [mapper]},
      &Utils.map_and_collapse_to_result(&1, fn element ->
        Trace.apply(mapper.(element), element)
      end)
    )
  end

  @spec get(path, default) :: Step.t(data, any | default) when default: any
  def get(path, default \\ nil) do
    path_as_list = List.wrap(path)

    Step.new({:get, [path, default]}, &__MODULE__.Get.call(&1, path_as_list, default))
  end

  @spec identity() :: Step.t(input, input) when input: any
  def identity do
    Step.new({:identity, []}, &Function.identity/1)
  end

  @spec into(intoable) :: Step.t(data, intoable) when intoable: Babel.Intoable.t()
  def into(intoable) do
    Step.new({:into, [intoable]}, &Babel.Intoable.into(intoable, &1))
  end

  @spec map(mapper :: Babel.t(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: data, output: any
  def map(mapper) do
    Step.new(
      {:map, [mapper]},
      &Utils.map_and_collapse_to_result(&1, fn element ->
        Trace.apply(mapper, element)
      end)
    )
  end

  @spec then(custom_name :: nil | any, function :: Step.fun(input, output)) ::
          Step.t(input, output)
        when input: any, output: any
  def then(custom_name \\ nil, function) do
    full_name = Enum.reject([custom_name, function], &is_nil/1)

    Step.new({:then, full_name}, function)
  end

  @spec try(nonempty_list(Babel.t(output))) :: Step.t(output) when output: any
  def try(applicables) do
    name = {:try, [applicables]}
    applicables = List.wrap(applicables)

    Step.new(name, &__MODULE__.Try.call(applicables, &1))
  end

  @spec try(Babel.t(output) | nonempty_list(Babel.t(output)), default) :: Step.t(output | default)
        when output: any, default: any
  def try(applicables, default) do
    name = {:try, [applicables, default]}
    applicables = List.wrap(applicables) ++ [const(default)]

    Step.new(name, &__MODULE__.Try.call(applicables, &1))
  end
end
