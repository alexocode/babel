defmodule Babel do
  readme = "README.md"

  @external_resource readme
  @moduledoc Babel.Docs.massage_readme(readme, for: "Babel")

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
  @type path :: Babel.Builtin.path()

  @doc """
  Returns true when the given value is a `Babel.Pipeline` or `Babel.Step`.

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
  defguard is_babel(babel) when is_struct(babel, Pipeline) or is_struct(babel, Step)

  @doc """
  Returns true when the given value is a `Babel.Pipeline` or `Babel.Step`.

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

    if Trace.ok?(trace) do
      trace.output
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

  @doc "Alias for `fetch/1`."
  @spec at(path) :: Step.t()
  def at(path), do: fetch(path)

  @doc "Alias for `fetch/2`."
  @spec at(t, path) :: t
  def at(babel, path) do
    fetch(babel, path)
  end

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name, [])

  @spec call(module, function_name :: atom) :: Step.t()
  defdelegate call(module, function_name), to: Babel.Builtin

  @spec call(t, module, function_name :: atom) :: t
  def call(babel, module, function_name) when is_babel(babel) do
    chain(babel, call(module, function_name))
  end

  @spec call(module, function_name :: atom, extra_args :: list) :: Step.t()
  defdelegate call(module, function_name, extra_args), to: Babel.Builtin

  @spec call(t, module, function_name :: atom, extra_args :: list) :: t
  def call(babel, module, function_name, extra_args) do
    chain(babel, call(module, function_name, extra_args))
  end

  @spec cast(:boolean) :: Step.t(boolean)
  @spec cast(:integer) :: Step.t(integer)
  @spec cast(:float) :: Step.t(float)
  defdelegate cast(type), to: Babel.Builtin

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

  @spec const(value) :: Step.t(value) when value: any
  defdelegate const(value), to: Babel.Builtin

  @spec fail(reason_or_function :: reason | (input -> reason)) :: Step.t(no_return)
        when input: any, reason: any
  defdelegate fail(reason_or_function), to: Babel.Builtin

  @spec fetch(path) :: Step.t()
  defdelegate fetch(path), to: Babel.Builtin

  @spec fetch(t(), path) :: t
  def fetch(babel, path) do
    chain(babel, fetch(path))
  end

  @spec flat_map((input -> t(input, output))) :: Step.t([output]) when input: data, output: term
  defdelegate flat_map(mapper), to: Babel.Builtin

  @spec flat_map(Pipeline.t(Enumerable.t(input)), (input -> t(input, output))) :: t([output])
        when input: data, output: term
  def flat_map(babel, mapper) do
    chain(babel, flat_map(mapper))
  end

  @spec get(path) :: Step.t()
  defdelegate get(path), to: Babel.Builtin

  @spec get(path, default :: any) :: Step.t()
  defdelegate get(path, default), to: Babel.Builtin

  @spec get(t(), path, default :: any) :: t
  def get(babel, path, default) do
    chain(babel, get(path, default))
  end

  @spec identity() :: Step.t(input, input) when input: any
  defdelegate identity, to: Babel.Builtin

  @spec into(intoable) :: Step.t(intoable) when intoable: Babel.Intoable.t()
  defdelegate into(intoable), to: Babel.Builtin

  @spec into(t(), intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel, intoable) do
    chain(babel, into(intoable))
  end

  @spec map(t(input, output)) :: Step.t([output]) when input: data, output: term
  defdelegate map(mapper), to: Babel.Builtin

  @spec map(Pipeline.t(Enumerable.t(input)), t(input, output)) :: t([output])
        when input: data, output: term
  def map(babel, mapper) do
    chain(babel, map(mapper))
  end

  @spec match((input -> t(input, output))) :: Step.t(output) when input: data, output: term
  defdelegate match(chooser), to: Babel.Builtin

  @spec match(t(), (input -> t(input, output))) :: t(output)
        when input: data, output: term
  def match(babel, chooser) do
    chain(babel, match(chooser))
  end

  @doc "Alias for `identity/0`."
  @spec noop() :: Step.t(input, input) when input: any
  def noop, do: identity()

  @spec on_error(t(), Pipeline.on_error(output)) :: t(output) when output: any
  def on_error(babel, function) do
    babel
    |> Pipeline.new()
    |> Pipeline.on_error(function)
  end

  @spec then(Step.func(input, output)) :: Step.t(output) when input: any, output: any
  defdelegate then(function), to: Babel.Builtin

  @spec then(t(input), Step.func(input, output)) :: t(output)
        when input: data, output: term
  def then(babel, function) when is_babel(babel) do
    chain(babel, then(function))
  end

  @spec then(name, Step.func(input, output)) :: Step.t(output) when input: any, output: any
  defdelegate then(descriptive_name, function), to: Babel.Builtin

  @spec then(t(input), name, Step.func(input, output)) :: t(output)
        when input: data, output: term
  def then(babel, descriptive_name, function) when is_babel(babel) do
    chain(babel, then(descriptive_name, function))
  end

  @spec trace(t(input, output), data) :: Trace.t(input, output) when input: any, output: any
  defdelegate trace(babel, data), to: Trace, as: :apply

  @spec try(applicables :: nonempty_list(t(output))) :: Step.t(output)
        when output: any
  defdelegate try(applicables), to: Babel.Builtin

  @spec try(t(input), applicables :: nonempty_list(t(input, output))) :: t(input, output)
        when input: any, output: any
  def try(babel, applicables) when is_babel(babel) do
    chain(babel, __MODULE__.try(applicables))
  end

  @spec try(applicables :: t(output) | nonempty_list(t(output)), default) :: t(output | default)
        when output: any, default: any
  defdelegate try(applicables, default), to: Babel.Builtin

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
