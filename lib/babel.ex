defmodule Babel do
  import Kernel, except: [apply: 2]

  alias Babel.Applicable
  alias Babel.Core
  alias Babel.Error
  alias Babel.Pipeline
  alias Babel.Step

  @type t :: Applicable.t()
  @type t(output) :: Applicable.t(output)
  @type t(input, output) :: Applicable.t(input, output)

  @typedoc "Arbitrary data structure that ought to be transformed."
  @type data :: term

  @typedoc "Arbitrary term describing a Babel step or pipeline."
  @type name :: term

  @typedoc "TODO: Better docs"
  @type path :: Core.path()

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
  defdelegate id, to: Core

  @spec const(value) :: Step.t(value) when value: any
  defdelegate const(value), to: Core

  @doc "Alias for `fetch/2`."
  @spec at(t | nil, path) :: t
  def at(babel \\ nil, path), do: fetch(babel, path)

  @spec fetch(t | nil, path) :: t
  def fetch(babel \\ nil, path) do
    chain(babel, Core.fetch(path))
  end

  @spec get(t | nil, path) :: t
  def get(babel \\ nil, path, default) do
    chain(babel, Core.get(path, default))
  end

  @spec cast(t | nil, :boolean) :: t(boolean)
  @spec cast(t | nil, :integer) :: t(integer)
  @spec cast(t | nil, :float) :: t(float)
  def cast(babel \\ nil, target) do
    chain(babel, Core.cast(target))
  end

  @spec into(t | nil, intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel \\ nil, intoable) do
    chain(babel, Core.into(intoable))
  end

  @spec then(t(input) | nil, name, Step.fun(input, output)) :: t(output)
        when input: data, output: term
  def then(babel \\ nil, name \\ nil, function) do
    chain(babel, Step.new(name, function))
  end

  @spec call(t | nil, module, function_name :: atom) :: t
  @spec call(t | nil, module, function_name :: atom, extra_args :: list) :: t
  def call(babel \\ nil, module, function_name, extra_args \\ []) do
    chain(babel, Core.call(module, function_name, extra_args))
  end

  @spec choice(t(input) | nil, (input -> t(input, output))) :: t(output)
        when input: data, output: term
  def choice(babel \\ nil, chooser) do
    chain(babel, Core.choice(chooser))
  end

  @spec map(t(Enumerable.t(input)) | nil, t(input, output)) :: t([output])
        when input: data, output: term
  def map(babel \\ nil, mapper) do
    chain(babel, Core.map(mapper))
  end

  @spec flat_map(t(Enumerable.t(input)) | nil, (input -> t(input, output))) :: t([output])
        when input: data, output: term
  def flat_map(babel \\ nil, mapper) do
    chain(babel, Core.flat_map(mapper))
  end

  @spec chain(nil, next) :: next when next: t
  @spec chain(t(input, in_between), next :: t(in_between, output)) :: Pipeline.t(input, output)
        when input: any, in_between: any, output: any
  def chain(nil, next), do: next

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
    Babel.Applicable.apply(babel, data)
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
end
