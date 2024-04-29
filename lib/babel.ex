defmodule Babel do
  import Kernel, except: [apply: 2, then: 2]

  alias Babel.Applicable
  alias Babel.Error
  alias Babel.Pipeline
  alias Babel.Step
  alias Babel.Trace

  @type t :: Applicable.t()
  @type t(output) :: Applicable.t(output)
  @type t(input, output) :: Applicable.t(input, output)

  @type result(output) :: output | {:ok, output} | :error | {:error, reason :: any}

  @typedoc "Arbitrary data structure that ought to be transformed."
  @type data :: term

  @typedoc "Arbitrary term describing a Babel step or pipeline."
  @type name :: term

  @typedoc "TODO: Better docs"
  @type path :: Core.path()

  defguard is_babel(babel) when is_struct(babel, Babel.Pipeline) or is_struct(babel, Babel.Step)

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

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name, [])

  @doc "Alias for `id/0`."
  @spec noop() :: Step.t(input, input) when input: any
  def noop, do: id()

  @spec id() :: Step.t(input, input) when input: any
  defdelegate id, to: Babel.Core

  @spec const(value) :: Step.t(value) when value: any
  defdelegate const(value), to: Babel.Core

  @doc "Alias for `fetch/2`."
  @spec at(path) :: t
  def at(path), do: fetch(path)

  @doc "Alias for `fetch/2`."
  @spec at(t, path) :: t
  def at(babel, path) do
    fetch(babel, path)
  end

  @spec fetch(path) :: t
  defdelegate fetch(path), to: Babel.Core

  @spec fetch(t(), path) :: t
  def fetch(babel, path) do
    chain(babel, fetch(path))
  end

  @spec get(path, default :: any) :: t
  defdelegate get(path, default), to: Babel.Core

  @spec get(t(), path, default :: any) :: t
  def get(babel, path, default) do
    chain(babel, get(path, default))
  end

  @spec cast(:boolean) :: t(boolean)
  @spec cast(:integer) :: t(integer)
  @spec cast(:float) :: t(float)
  defdelegate cast(type), to: Babel.Core

  @spec cast(t(), :boolean) :: t(boolean)
  @spec cast(t(), :integer) :: t(integer)
  @spec cast(t(), :float) :: t(float)
  def cast(babel, target) do
    chain(babel, cast(target))
  end

  @spec into(intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  defdelegate into(intoable), to: Babel.Core

  @spec into(t(), intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel, intoable) do
    chain(babel, into(intoable))
  end

  @spec then(Step.fun(input, output)) :: t(output) when input: any, output: any
  defdelegate then(function), to: Babel.Core

  @spec then(t(input), Step.fun(input, output)) :: t(output)
        when input: data, output: term
  def then(babel, function) when is_babel(babel) do
    chain(babel, then(function))
  end

  @spec then(name, Step.fun(input, output)) :: t(output) when input: any, output: any
  defdelegate then(descriptive_name, function), to: Babel.Core

  @spec then(t(input), name, Step.fun(input, output)) :: t(output)
        when input: data, output: term
  def then(babel, descriptive_name, function) when is_babel(babel) do
    chain(babel, then(descriptive_name, function))
  end

  @spec call(module, function_name :: atom) :: t
  defdelegate call(module, function_name), to: Babel.Core

  @spec call(t, module, function_name :: atom) :: t
  def call(babel, module, function_name) when is_babel(babel) do
    chain(babel, call(module, function_name))
  end

  @spec call(module, function_name :: atom, extra_args :: list) :: t
  defdelegate call(module, function_name, extra_args), to: Babel.Core

  @spec call(t, module, function_name :: atom, extra_args :: list) :: t
  def call(babel, module, function_name, extra_args) do
    chain(babel, call(module, function_name, extra_args))
  end

  @spec choice((input -> t(input, output))) :: t(output) when input: data, output: term
  defdelegate choice(chooser), to: Babel.Core

  @spec choice(t(), (input -> t(input, output))) :: t(output)
        when input: data, output: term
  def choice(babel, chooser) do
    chain(babel, choice(chooser))
  end

  @spec map(t(input, output)) :: t([output]) when input: data, output: term
  defdelegate map(mapper), to: Babel.Core

  @spec map(Pipeline.t(Enumerable.t(input)), t(input, output)) :: t([output])
        when input: data, output: term
  def map(babel, mapper) do
    chain(babel, map(mapper))
  end

  @spec flat_map((input -> t(input, output))) :: t([output]) when input: data, output: term
  defdelegate flat_map(mapper), to: Babel.Core

  @spec flat_map(Pipeline.t(Enumerable.t(input)), (input -> t(input, output))) :: t([output])
        when input: data, output: term
  def flat_map(babel, mapper) do
    chain(babel, flat_map(mapper))
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

  @spec on_error(t(), Pipeline.on_error(output)) :: t(output) when output: any
  def on_error(babel, function) do
    babel
    |> Pipeline.new()
    |> Pipeline.on_error(function)
  end

  @spec apply(t(output), data) :: {:ok, output} | {:error, Error.t()} when output: any
  def apply(babel, data) do
    trace = trace(babel, data)

    if Trace.ok?(trace) do
      trace.result
    else
      {:error, Error.new(trace)}
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

  @spec trace(t(input, output), data) :: Trace.t(input, output) when input: any, output: any
  defdelegate trace(babel, data), to: Trace, as: :apply
end
