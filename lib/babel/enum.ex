defmodule Babel.Enum.Lifting do
  @moduledoc false

  alias Babel.Step

  require Step

  defmacro deflifted(call) do
    {name, [babel | args]} = name_and_args(call)

    doc = """
    Returns a Babel struct that wraps `Enum.#{name}/#{1 + length(args)}`.

    See the moduledoc for further details.
    """

    q =
      quote location: :keep do
        @doc unquote(doc)
        def unquote(call) do
          unquote(__MODULE__).wrap(unquote(babel), unquote(name), unquote(args))
        end
      end

    # q
    # |> Macro.to_string()
    # |> IO.puts()

    q
  end

  defp name_and_args({:when, _, [call | _guards]}) do
    name_and_args(call)
  end

  defp name_and_args({name, _, args}) do
    {name, without_defaults!(name, args)}
  end

  defp without_defaults!(name, args) do
    Enum.each(args, fn
      {:\\, _, [_var | _]} = default ->
        raise ArgumentError,
              "default found where none expected(#{name}): " <> Macro.to_string(default)

      _ ->
        :ok
    end)

    args
  end

  @spec wrap(Babel.Enum.t(), func_name :: atom, args :: list) :: Babel.Enum.t()
  def wrap(babel, func_name, args) when is_atom(func_name) and is_list(args) do
    wrap(babel, {func_name, args}, &apply(Elixir.Enum, func_name, [&1 | args]))
  end

  @spec wrap(
          Step.t(input, in_between),
          name :: Step.name(),
          function :: Step.step_fun(in_between, output)
        ) :: Step.t(input, output)
        when input: any, in_between: in_between, output: any
  def wrap(%Step{} = step, name, function) when Step.is_step_function(function) do
    Step.chain([
      step,
      Step.new(name, function)
    ])
  end
end

defmodule Babel.Enum do
  alias Babel.Step

  import __MODULE__.Lifting

  require Step

  @type t :: Step.t(any, enum)
  @type t(output) :: Step.t(enum, output)
  @type enum :: Enum.t()
  @type acc :: any
  @type element :: any
  @type default :: any

  @typedoc "Zero-based index. It can also be a negative integer."
  @type index :: integer

  @spec all?(t) :: t(boolean)
  deflifted all?(babel)

  @spec all?(t, (element -> as_boolean(term))) :: t(boolean)
  deflifted all?(babel, fun)

  @spec any?(t) :: t(boolean)
  deflifted any?(babel)

  @spec any?(t, (element -> as_boolean(term))) :: t(boolean)
  deflifted any?(babel, fun)

  @spec at(t, index) :: t(element | default)
  deflifted at(babel, index) when is_integer(index)
  @spec at(t, index, default) :: t(element | default)
  deflifted at(babel, index, default) when is_integer(index)

  @spec chunk_every(t, pos_integer) :: t([list()])
  deflifted chunk_every(babel, count)

  @spec chunk_every(t, pos_integer, pos_integer) :: t([list()])
  deflifted chunk_every(babel, count, step)
            when is_integer(count) and count > 0 and is_integer(step) and step > 0

  @spec chunk_every(t, pos_integer, pos_integer, enum | :discard) :: t([list()])
  deflifted chunk_every(babel, count, step, leftover)
            when is_integer(count) and count > 0 and is_integer(step) and step > 0

  @spec chunk_while(t, acc, chunk_fun, after_fun) :: t(enum)
        when chunk: any,
             chunk_fun: (element, acc -> {:cont, chunk, acc} | {:cont, acc} | {:halt, acc}),
             after_fun: (acc -> {:cont, chunk, acc} | {:cont, acc})
  deflifted chunk_while(babel, acc, chunk_fun, after_fun)

  @spec chunk_by(t, (element -> any)) :: t([list])
  deflifted chunk_by(babel, fun)

  @spec count(t) :: t(non_neg_integer)
  deflifted count(babel)

  @spec count(t, (element -> as_boolean(term))) :: t(non_neg_integer)
  deflifted count(babel, fun)

  @spec count_until(t, pos_integer) :: t(non_neg_integer)
  deflifted count_until(babel, limit) when is_integer(limit) and limit > 0

  @spec count_until(t, (element -> as_boolean(term)), pos_integer) :: t(non_neg_integer)
  deflifted count_until(babel, fun, limit) when is_integer(limit) and limit > 0

  @spec dedup(t) :: t(list)
  deflifted dedup(babel)

  @spec dedup_by(t, (element -> term)) :: t(list)
  deflifted dedup_by(babel, fun)

  @spec drop(t, integer) :: t(list)
  deflifted drop(babel, amount) when is_integer(amount)

  @spec drop_every(t, non_neg_integer) :: t(list)
  deflifted drop_every(babel, nth) when is_integer(nth) and nth >= 0

  @spec drop_while(t, (element -> as_boolean(term))) :: t(list)
  deflifted drop_while(babel, fun)

  @spec empty?(t) :: t(boolean)
  deflifted empty?(babel)

  @spec filter(t, (element -> as_boolean(term))) :: t(list)
  deflifted filter(babel, fun)

  @spec find(t, (element -> any)) :: t(element | default)
  deflifted find(babel, fun)
  @spec find(t, default, (element -> any)) :: t(element | default)
  deflifted find(babel, default, fun)

  @spec find_index(t, (element -> any)) :: t(non_neg_integer | nil)
  deflifted find_index(babel, fun)

  @spec find_value(t, (element -> any)) :: t(any | nil)
  deflifted find_value(babel, fun)
  @spec find_value(t, default, (element -> any)) :: t(any | nil)
  deflifted find_value(babel, default, fun)

  @spec flat_map(t, (element -> t)) :: t(list)
  deflifted flat_map(babel, fun)

  @spec flat_map_reduce(t, acc, fun) :: t({[any], acc})
        when fun: (element, acc -> {t, acc} | {:halt, acc})
  deflifted flat_map_reduce(babel, acc, fun)

  @spec frequencies(t) :: t(map)
  deflifted frequencies(babel)

  @spec frequencies_by(t, (element -> any)) :: t(map)
  deflifted frequencies_by(babel, key_fun) when is_function(key_fun, 1)

  @spec group_by(t, (element -> any)) :: map
  deflifted group_by(babel, key_fun) when is_function(key_fun, 1)
  @spec group_by(t, (element -> any), (element -> any)) :: map
  deflifted group_by(babel, key_fun, value_fun)
            when is_function(key_fun, 1) and is_function(value_fun, 1)

  @spec intersperse(t, element) :: t(list)
  deflifted intersperse(babel, separator)

  # TODO: Custom impl for this?
  # @spec into(t(), Collectable.t()) :: t(Collectable.t())
  # deflifted into(babel, collectable)

  # @spec into(t(), Collectable.t(), (term -> term)) :: t(Collectable.t())
  # deflifted into(babel, collectable, transform) do

  @spec join(t) :: t(String.t())
  @spec join(t, String.t()) :: t(String.t())
  deflifted join(babel)
  deflifted join(babel, joiner)

  @spec map(t, (element -> any)) :: t(list)
  deflifted map(babel, fun)

  @spec map_every(t, non_neg_integer, (element -> any)) :: t(list)
  deflifted map_every(babel, nth, fun)

  @spec map_intersperse(t, element(), (element -> any())) :: t(list)
  deflifted map_intersperse(babel, separator, mapper)

  @spec map_join(t, (element -> String.Chars.t())) :: t(String.t())
  @spec map_join(t, String.t(), (element -> String.Chars.t())) :: t(String.t())
  deflifted map_join(babel, mapper)
  deflifted map_join(babel, joiner, mapper) when is_binary(joiner)

  @spec map_reduce(t, acc, (element, acc -> {element, acc})) :: t({list, acc})
  deflifted map_reduce(babel, acc, fun)

  @spec max(t) :: t(element | no_return)
  @spec max(t, (-> empty_result)) :: t(element | empty_result) when empty_result: any
  @spec max(t, (element, element -> boolean) | module()) ::
          element | empty_result
        when empty_result: any
  @spec max(t, (element, element -> boolean) | module(), (-> empty_result)) ::
          element | empty_result
        when empty_result: any
  deflifted max(babel)
  deflifted max(babel, empty_fallback)
  deflifted max(babel, sorter, empty_fallback)

  @spec max_by(t, (element -> any), empty_fallback) :: t(element | empty_result)
        when empty_result: any,
             empty_fallback: (-> empty_result) | (element, element -> boolean) | module()
  deflifted max_by(babel, fun, empty_fallback)
            when is_function(fun, 1) and is_function(empty_fallback, 0)
end
