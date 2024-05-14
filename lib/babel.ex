defmodule Babel do
  readme = "README.md"

  @external_resource readme
  @moduledoc Babel.Docs.massage_readme(readme, for: "Babel")

  import Kernel, except: [apply: 2, then: 2]

  alias Babel.Applicable
  alias Babel.Builtin
  alias Babel.Error
  alias Babel.Pipeline
  alias Babel.Step
  alias Babel.Trace

  require Builtin

  @type t :: Applicable.t()
  @type t(output) :: Applicable.t(output)
  @type t(input, output) :: Applicable.t(input, output)

  @typedoc "Arbitrary data structure that ought to be transformed."
  @type data :: term

  @typedoc "Arbitrary term describing a Babel step or pipeline."
  @type name :: term

  @typedoc "TODO: Better docs"
  @type path :: term | [term]

  @doc """
  Returns true when the given value is a `Babel.Pipeline` or a built-in `Babel.Step`.

  ## Examples

      iex> Babel.is_babel(Babel.identity())
      true

      iex> pipeline = :my_pipeline |> Babel.begin() |> Babel.fetch([:foo, :bar]) |> Babel.map(Babel.cast(:integer))
      iex> Babel.is_babel(pipeline)
      true

      iex> Babel.is_babel(:something)
      false

      iex> Babel.is_babel("different")
      false
  """
  # We're deliberately not using `is_struct/2` here for backwards compatibility
  defguard is_babel(babel)
           when Builtin.struct_module(babel) == Pipeline or Builtin.is_builtin(babel)

  @doc """
  Returns true when the given value is a `Babel.Pipeline` or a built-in `Babel.Step`.

  ## Examples

      iex> Babel.babel?(Babel.identity())
      true

      iex> pipeline = :my_pipeline |> Babel.begin() |> Babel.fetch([:foo, :bar]) |> Babel.map(Babel.cast(:integer))
      iex> Babel.babel?(pipeline)
      true

      iex> Babel.babel?(:something)
      false

      iex> Babel.babel?("different")
      false
  """
  def babel?(babel), do: is_babel(babel)

  defmacro pipeline(name, [{:do, do_block} | maybe_else]) do
    case maybe_else do
      [] ->
        quote do
          Babel.Pipeline.new(unquote(name), unquote(do_block))
        end

      [else: else_block] ->
        on_error = {:fn, [], else_block}

        quote do
          Babel.Pipeline.new(unquote(name), unquote(on_error), unquote(do_block))
        end
    end
  end

  @spec apply(t(output), data) :: {:ok, output} | {:error, Error.t()} when output: any
  def apply(babel, data) do
    trace = trace(babel, data)

    case Trace.result(trace) do
      {:ok, value} -> {:ok, value}
      {:error, _} -> {:error, Error.new(trace)}
    end
  end

  @spec apply!(t(output), data) :: output | no_return when output: any
  def apply!(babel, data) do
    case apply(babel, data) do
      {:ok, output} ->
        output

      {:error, %Error{} = error} ->
        raise error
    end
  end

  @doc "Alias for `fetch/1`."
  @spec at(path) :: t
  def at(path), do: fetch(path)

  @doc "Alias for `fetch/2`."
  @spec at(t, path) :: t
  def at(babel, path) do
    fetch(babel, path)
  end

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name, [])

  @spec call(module, function_name :: atom) :: t
  defdelegate call(module, function_name), to: Builtin.Call, as: :new

  @spec call(t, module, function_name :: atom) :: t
  def call(babel, module, function_name) when is_babel(babel) do
    chain(babel, call(module, function_name))
  end

  @spec call(module, function_name :: atom, extra_args :: list) :: t
  defdelegate call(module, function_name, extra_args), to: Builtin.Call, as: :new

  @spec call(t, module, function_name :: atom, extra_args :: list) :: t
  def call(babel, module, function_name, extra_args) do
    chain(babel, call(module, function_name, extra_args))
  end

  @spec cast(:boolean) :: t(boolean)
  @spec cast(:integer) :: t(integer)
  @spec cast(:float) :: t(float)
  defdelegate cast(type), to: Builtin.Cast, as: :new

  @spec cast(t(), :boolean) :: t(boolean)
  @spec cast(t(), :integer) :: t(integer)
  @spec cast(t(), :float) :: t(float)
  def cast(babel, target) do
    chain(babel, cast(target))
  end

  @spec chain(nil, next) :: next when next: t
  def chain(nil, next), do: next

  @spec chain(t(input, in_between), next :: t(in_between, output)) :: Pipeline.t(input, output)
        when input: any, in_between: any, output: any
  def chain(babel, next) do
    babel
    |> Pipeline.new()
    |> Pipeline.chain(next)
  end

  @spec const(value) :: t(value) when value: any
  defdelegate const(value), to: Builtin.Const, as: :new

  @doc "Alias for `match/1`."
  @spec choose((input -> t(input, output))) :: t(output) when input: data, output: term
  defdelegate choose(chooser), to: __MODULE__, as: :match

  @doc "Alias for `match/2`."
  @spec choose(t(), (input -> t(input, output))) :: t(output)
        when input: data, output: term
  defdelegate choose(babel, chooser), to: __MODULE__, as: :match

  @spec fail(reason_or_function :: reason | (input -> reason)) :: t(no_return)
        when input: any, reason: any
  defdelegate fail(reason_or_function), to: Builtin.Fail, as: :new

  @spec fetch(path) :: t
  defdelegate fetch(path), to: Builtin.Fetch, as: :new

  @spec fetch(t(), path) :: t
  def fetch(babel, path) do
    chain(babel, fetch(path))
  end

  @spec flat_map((input -> t(input, output))) :: t([output])
        when input: data, output: term
  defdelegate flat_map(mapper), to: Builtin.FlatMap, as: :new

  @spec flat_map(Pipeline.t(Enumerable.t(input)), (input -> t(input, output))) :: t([output])
        when input: data, output: term
  def flat_map(babel, mapper) do
    chain(babel, flat_map(mapper))
  end

  @spec get(path) :: t
  defdelegate get(path), to: Builtin.Get, as: :new

  @spec get(path, default :: any) :: t
  defdelegate get(path, default), to: Builtin.Get, as: :new

  @spec get(t(), path, default :: any) :: t
  def get(babel, path, default) do
    chain(babel, get(path, default))
  end

  @spec identity() :: t(input, input) when input: any
  defdelegate identity, to: Builtin.Identity, as: :new

  @spec into(intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  defdelegate into(intoable), to: Builtin.Into, as: :new

  @spec into(t(), intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel, intoable) do
    chain(babel, into(intoable))
  end

  @spec map(t(input, output)) :: t([output]) when input: data, output: term
  defdelegate map(mapper), to: Builtin.Map, as: :new

  @spec map(Pipeline.t(Enumerable.t(input)), t(input, output)) :: t([output])
        when input: data, output: term
  def map(babel, mapper) do
    chain(babel, map(mapper))
  end

  @spec match((input -> t(input, output))) :: t(output) when input: data, output: term
  defdelegate match(chooser), to: Builtin.Match, as: :new

  @spec match(t(), (input -> t(input, output))) :: t(output)
        when input: data, output: term
  def match(babel, chooser) do
    chain(babel, match(chooser))
  end

  @doc "Alias for `identity/0`."
  @spec noop() :: t(input, input) when input: any
  def noop, do: identity()

  @spec on_error(t(), Pipeline.on_error(output)) :: t(output) when output: any
  def on_error(babel, function) do
    babel
    |> Pipeline.new()
    |> Pipeline.on_error(function)
  end

  @spec then((input -> Step.result_or_trace(output))) :: t(output)
        when input: any, output: any
  defdelegate then(function), to: Builtin.Then, as: :new

  @spec then(t(input), (input -> Step.result_or_trace(output))) :: t(output)
        when input: data, output: term
  def then(babel, function) when is_babel(babel) do
    chain(babel, then(function))
  end

  @spec then(name, (input -> Step.result_or_trace(output))) :: t(output)
        when input: any, output: any
  defdelegate then(descriptive_name, function), to: Builtin.Then, as: :new

  @spec then(t(input), name, (input -> Step.result_or_trace(output))) :: t(output)
        when input: data, output: term
  def then(babel, descriptive_name, function) when is_babel(babel) do
    chain(babel, then(descriptive_name, function))
  end

  @spec trace(t(input, output), data) :: Trace.t(input, output) when input: any, output: any
  def trace(babel, data) do
    Babel.Applicable.apply(babel, Babel.Context.new(data))
  end

  @spec try(applicables :: nonempty_list(t(output))) :: t(output)
        when output: any
  defdelegate try(applicables), to: Builtin.Try, as: :new

  @spec try(t(input), applicables :: nonempty_list(t(input, output))) :: t(input, output)
        when input: any, output: any
  def try(babel, applicables) when is_babel(babel) do
    chain(babel, __MODULE__.try(applicables))
  end

  @spec try(applicables :: t(output) | nonempty_list(t(output)), default) :: t(output | default)
        when output: any, default: any
  defdelegate try(applicables, default), to: Builtin.Try, as: :new

  @spec try(
          t(input, output),
          applicables :: t(input, output) | nonempty_list(t(input, output)),
          default
        ) :: t(input, output | default)
        when input: any, output: any, default: any
  def try(babel, applicables, default) do
    chain(babel, __MODULE__.try(applicables, default))
  end
end
