defmodule Babel.Enum do
  alias Babel.Step

  import Babel.Lifting

  require Step

  @type t :: t(term)
  @type t(output) :: Babel.t(enum, output)
  @type pipeline(output) :: Babel.pipeline(output)

  @type enum :: Enum.t()
  @type acc :: any
  @type element :: any
  @type default :: any

  @typedoc "Zero-based index. It can also be a negative integer."
  @type index :: integer

  @spec all?(t) :: pipeline(boolean)
  deflifted all?(babel), from: Enum

  @spec all?(t, (element -> as_boolean(term))) :: pipeline(boolean)
  deflifted all?(babel, fun), from: Enum

  @spec any?(t) :: pipeline(boolean)
  deflifted any?(babel), from: Enum

  @spec any?(t, (element -> as_boolean(term))) :: pipeline(boolean)
  deflifted any?(babel, fun), from: Enum

  @spec at(t, index) :: pipeline(element | default)
  deflifted at(babel, index) when is_integer(index), from: Enum
  @spec at(t, index, default) :: pipeline(element | default)
  deflifted at(babel, index, default) when is_integer(index), from: Enum

  @spec chunk_every(t, pos_integer) :: pipeline([list()])
  deflifted chunk_every(babel, count), from: Enum

  @spec chunk_every(t, pos_integer, pos_integer) :: pipeline([list()])
  deflifted chunk_every(babel, count, step)
            when is_integer(count) and count > 0 and is_integer(step) and step > 0,
            from: Enum

  @spec chunk_every(t, pos_integer, pos_integer, enum | :discard) :: pipeline([list()])
  deflifted chunk_every(babel, count, step, leftover)
            when is_integer(count) and count > 0 and is_integer(step) and step > 0,
            from: Enum

  @spec chunk_while(t, acc, chunk_fun, after_fun) :: pipeline(enum)
        when chunk: any,
             chunk_fun: (element, acc -> {:cont, chunk, acc} | {:cont, acc} | {:halt, acc}),
             after_fun: (acc -> {:cont, chunk, acc} | {:cont, acc})
  deflifted chunk_while(babel, acc, chunk_fun, after_fun), from: Enum

  @spec chunk_by(t, (element -> any)) :: pipeline([list])
  deflifted chunk_by(babel, fun), from: Enum

  @spec count(t) :: pipeline(non_neg_integer)
  deflifted count(babel), from: Enum

  @spec count(t, (element -> as_boolean(term))) :: pipeline(non_neg_integer)
  deflifted count(babel, fun), from: Enum

  @spec count_until(t, pos_integer) :: pipeline(non_neg_integer)
  deflifted count_until(babel, limit) when is_integer(limit) and limit > 0, from: Enum

  @spec count_until(t, (element -> as_boolean(term)), pos_integer) :: pipeline(non_neg_integer)
  deflifted count_until(babel, fun, limit) when is_integer(limit) and limit > 0, from: Enum

  @spec dedup(t) :: pipeline(list)
  deflifted dedup(babel), from: Enum

  @spec dedup_by(t, (element -> term)) :: pipeline(list)
  deflifted dedup_by(babel, fun), from: Enum

  @spec drop(t, integer) :: pipeline(list)
  deflifted drop(babel, amount) when is_integer(amount), from: Enum

  @spec drop_every(t, non_neg_integer) :: pipeline(list)
  deflifted drop_every(babel, nth) when is_integer(nth) and nth >= 0, from: Enum

  @spec drop_while(t, (element -> as_boolean(term))) :: pipeline(list)
  deflifted drop_while(babel, fun), from: Enum

  @spec empty?(t) :: pipeline(boolean)
  deflifted empty?(babel), from: Enum

  @spec filter(t, (element -> as_boolean(term))) :: pipeline(list)
  deflifted filter(babel, fun), from: Enum

  @spec find(t, (element -> any)) :: pipeline(element | default)
  deflifted find(babel, fun), from: Enum
  @spec find(t, default, (element -> any)) :: pipeline(element | default)
  deflifted find(babel, default, fun), from: Enum

  @spec find_index(t, (element -> any)) :: pipeline(non_neg_integer | nil)
  deflifted find_index(babel, fun), from: Enum

  @spec find_value(t, (element -> any)) :: pipeline(any | nil)
  deflifted find_value(babel, fun), from: Enum
  @spec find_value(t, default, (element -> any)) :: pipeline(any | nil)
  deflifted find_value(babel, default, fun), from: Enum

  @spec flat_map(t, (element -> enum)) :: pipeline(list)
  deflifted flat_map(babel, fun), from: Enum

  @spec flat_map_reduce(t, acc, fun) :: pipeline({[any], acc})
        when fun: (element, acc -> {enum, acc} | {:halt, acc})
  deflifted flat_map_reduce(babel, acc, fun), from: Enum

  @spec frequencies(t) :: pipeline(map)
  deflifted frequencies(babel), from: Enum

  @spec frequencies_by(t, (element -> any)) :: pipeline(map)
  deflifted frequencies_by(babel, key_fun) when is_function(key_fun, 1), from: Enum

  @spec group_by(t, (element -> any)) :: map
  deflifted group_by(babel, key_fun) when is_function(key_fun, 1), from: Enum
  @spec group_by(t, (element -> any), (element -> any)) :: map
  deflifted group_by(babel, key_fun, value_fun)
            when is_function(key_fun, 1) and is_function(value_fun, 1),
            from: Enum

  @spec intersperse(t, element) :: pipeline(list)
  deflifted intersperse(babel, separator), from: Enum

  # TODO: Custom impl for this?
  # @spec into(t(), Collectable.t()) :: pipeline(Collectable.t())
  # deflifted into(babel, collectable), from:   Enum

  # @spec into(t(), Collectable.t(), (term -> term)) :: pipeline(Collectable.t())
  # deflifted into(babel, collectable, transform) do, from:   Enum

  @spec join(t) :: pipeline(String.t())
  @spec join(t, String.t()) :: pipeline(String.t())
  deflifted join(babel), from: Enum
  deflifted join(babel, joiner), from: Enum

  @spec map(t, (element -> any)) :: pipeline(list)
  deflifted map(babel, fun), from: Enum

  @spec map_every(t, non_neg_integer, (element -> any)) :: pipeline(list)
  deflifted map_every(babel, nth, fun), from: Enum

  @spec map_intersperse(t, element(), (element -> any())) :: pipeline(list)
  deflifted map_intersperse(babel, separator, mapper), from: Enum

  @spec map_join(t, (element -> String.Chars.t())) :: pipeline(String.t())
  @spec map_join(t, String.t(), (element -> String.Chars.t())) :: pipeline(String.t())
  deflifted map_join(babel, mapper), from: Enum
  deflifted map_join(babel, joiner, mapper) when is_binary(joiner), from: Enum

  @spec map_reduce(t, acc, (element, acc -> {element, acc})) :: pipeline({list, acc})
  deflifted map_reduce(babel, acc, fun), from: Enum

  @spec max(t) :: pipeline(element | no_return)
  @spec max(t, (-> empty_result)) :: pipeline(element | empty_result) when empty_result: any
  @spec max(t, (element, element -> boolean) | module()) ::
          t(element | empty_result)
        when empty_result: any
  @spec max(t, (element, element -> boolean) | module(), (-> empty_result)) ::
          t(element | empty_result)
        when empty_result: any
  deflifted max(babel), from: Enum
  deflifted max(babel, empty_fallback), from: Enum
  deflifted max(babel, sorter, empty_fallback), from: Enum

  @spec max_by(t, (element -> any), (-> empty_result) | (element, element -> boolean) | module()) ::
          t(element | empty_result)
        when empty_result: any
  deflifted max_by(babel, fun, empty_fallback)
            when is_function(fun, 1),
            from: Enum

  @spec max_by(
          t,
          (element -> any),
          (element, element -> boolean) | module(),
          (-> empty_result)
        ) :: pipeline(element | empty_result)
        when empty_result: any
  deflifted max_by(babel, fun, sorter, empty_fallback)
            when is_function(fun, 1),
            from: Enum

  @spec member?(t, element) :: pipeline(boolean)
  deflifted member?(babel, element), from: Enum

  @spec min(t) :: pipeline(element | no_return)
  @spec min(t, (-> empty_result)) :: pipeline(element | empty_result) when empty_result: any
  @spec min(t, (element, element -> boolean) | module()) ::
          t(element | empty_result)
        when empty_result: any
  @spec min(t, (element, element -> boolean) | module(), (-> empty_result)) ::
          t(element | empty_result)
        when empty_result: any
  deflifted min(babel), from: Enum
  deflifted min(babel, empty_fallback), from: Enum
  deflifted min(babel, sorter, empty_fallback), from: Enum

  @spec min_by(t, (element -> any), (-> empty_result) | (element, element -> boolean) | module()) ::
          t(element | empty_result)
        when empty_result: any
  deflifted min_by(babel, fun, empty_fallback) when is_function(fun, 1), from: Enum

  @spec min_by(
          t,
          (element -> any),
          (element, element -> boolean) | module(),
          (-> empty_result)
        ) :: pipeline(element | empty_result)
        when empty_result: any
  deflifted min_by(babel, fun, sorter, empty_fallback) when is_function(fun, 1), from: Enum

  @spec min_max(t) :: pipeline({element, element} | no_return)
  deflifted min_max(babel), from: Enum

  @spec min_max(t, (-> empty_result)) :: pipeline({element, element} | empty_result)
        when empty_result: any
  deflifted min_max(babel, empty_fallback), from: Enum

  @spec min_max_by(t, (element -> any), (-> empty_result)) :: {element, element} | empty_result
        when empty_result: any
  @spec min_max_by(t, (element -> any), (element, element -> boolean) | module()) ::
          t({element, element} | no_return)
  deflifted min_max_by(babel, fun, empty_fallback) when is_function(fun, 1), from: Enum

  @spec min_max_by(
          t,
          (element -> any),
          (element, element -> boolean) | module(),
          (-> empty_result)
        ) :: pipeline({element, element} | empty_result)
        when empty_result: any
  deflifted min_max_by(babel, fun, sorter, empty_fallback) when is_function(fun, 1), from: Enum

  @spec split_with(t, (element -> as_boolean(term))) :: pipeline({list, list})
  deflifted split_with(babel, fun), from: Enum

  @spec random(t) :: pipeline(element)
  deflifted random(babel), from: Enum

  @spec reduce(t, (element, acc -> acc)) :: pipeline(acc)
  deflifted reduce(babel, fun), from: Enum
  @spec reduce(t, acc, (element, acc -> acc)) :: pipeline(acc)
  deflifted reduce(babel, acc, fun), from: Enum

  @spec reduce_while(t, acc, (element, acc -> {:cont, acc} | {:halt, halted})) ::
          pipeline(acc | halted)
        when acc: any, halted: any
  deflifted reduce_while(babel, acc, fun), from: Enum

  @spec reject(t, (element -> as_boolean(term))) :: pipeline(list)
  deflifted reject(babel, fun), from: Enum

  @spec reverse(t) :: pipeline(list)
  deflifted reverse(babel), from: Enum

  @spec reverse(t, enum) :: pipeline(list)
  deflifted reverse(babel, tail), from: Enum

  @spec reverse_slice(t, non_neg_integer, non_neg_integer) :: pipeline(list)
  deflifted reverse_slice(babel, start_index, count)
            when is_integer(start_index) and start_index >= 0 and is_integer(count) and count >= 0,
            from: Enum

  @spec slide(t, Range.t() | index, index) :: pipeline(list)
  deflifted slide(babel, range_or_single_index, insertion_index), from: Enum

  @spec scan(t, (element, acc -> acc)) :: pipeline(list(acc)) when acc: any
  deflifted scan(babel, fun), from: Enum
  @spec scan(t, acc, (element, acc -> acc)) :: pipeline(list(acc)) when acc: any
  deflifted scan(babel, acc, fun), from: Enum

  @spec shuffle(t) :: pipeline(list)
  deflifted shuffle(babel), from: Enum

  @spec slice(t, Range.t()) :: pipeline(list)
  deflifted slice(babel, index_range), from: Enum

  @spec slice(t, index, non_neg_integer) :: pipeline(list)
  deflifted slice(babel, start_index, amount)
            when is_integer(start_index) and is_integer(amount),
            from: Enum

  @spec sort(t) :: pipeline(list)
  deflifted sort(babel), from: Enum

  @spec sort(
          t,
          (element, element -> boolean) | :asc | :desc | module() | {:asc | :desc, module()}
        ) :: pipeline(list)
  deflifted sort(babel, sorter), from: Enum

  @spec sort_by(t, (element -> mapped_element)) :: pipeline(list) when mapped_element: element
  deflifted sort_by(babel, mapper), from: Enum

  @spec sort_by(
          t,
          (element -> mapped_element),
          (element, element -> boolean) | :asc | :desc | module() | {:asc | :desc, module()}
        ) :: pipeline(list)
        when mapped_element: element
  deflifted sort_by(babel, mapper, sorter), from: Enum

  @spec split(t, integer) :: pipeline({list, list})
  deflifted split(babel, count) when is_integer(count), from: Enum

  @spec split_while(t, (element -> as_boolean(term))) :: pipeline({list, list})
  deflifted split_while(babel, fun), from: Enum

  @spec sum(t) :: pipeline(number)
  deflifted sum(babel), from: Enum

  @spec product(t) :: pipeline(number)
  deflifted product(babel), from: Enum

  @spec take(t, integer) :: pipeline(list)
  deflifted take(babel, amount) when is_integer(amount), from: Enum

  @spec take_every(t, non_neg_integer) :: pipeline(list)
  deflifted take_every(babel, nth) when is_integer(nth) and nth >= 0, from: Enum

  @spec take_random(t, non_neg_integer) :: pipeline(list)
  deflifted take_random(babel, count) when is_integer(count) and count >= 0, from: Enum

  @spec take_while(t, (element -> as_boolean(term))) :: pipeline(list)
  deflifted take_while(babel, fun), from: Enum

  @spec to_list(t) :: pipeline([element])
  deflifted to_list(babel), from: Enum

  @spec uniq(t) :: pipeline(list)
  deflifted uniq(babel), from: Enum

  @spec uniq_by(t, (element -> term)) :: pipeline(list)
  deflifted uniq_by(babel, fun), from: Enum

  @spec unzip(t) :: pipeline({[element], [element]})
  deflifted unzip(babel), from: Enum

  @spec with_index(t, integer) :: pipeline([{term, integer}])
  deflifted with_index(babel), from: Enum
  @spec with_index(t, (element, index -> value)) :: pipeline([value]) when value: any
  deflifted with_index(babel, fun_or_offset), from: Enum

  @spec zip(t, enum) :: pipeline([{any, any}])
  deflifted zip(babel, enumerable2), from: Enum

  @spec zip_with(t, enum, (enum1_elem :: term, enum2_elem :: term -> zipped)) ::
          pipeline([zipped])
        when zipped: term
  deflifted zip_with(babel, enumerable2, zip_fun) when is_function(zip_fun, 2), from: Enum

  @spec zip_reduce(t, enum, acc, (enum1_elem :: term, enum2_elem :: term, acc -> acc)) ::
          pipeline(acc)
        when acc: term
  deflifted zip_reduce(babel, right, acc, reducer) when is_function(reducer, 3), from: Enum

  @spec zip_reduce(t, acc, ([term], acc -> acc)) :: pipeline(acc) when acc: term
  deflifted zip_reduce(babel, acc, reducer) when is_function(reducer, 2), from: Enum
end
