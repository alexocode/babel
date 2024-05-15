readme = "README.md"

supports_composition =
  "Supports composition (you can pipe into this to create a `Babel.Pipeline`)."

defmodule Babel do
  use Babel.EnforceVersion,
    otp: ">= 21.0.0",
    elixir: ">= 1.9.0"

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

  @doc """
  Tries to transform the given `data` as described by the given `Babel.Applicable`.

  If the `Babel.Applicable` transforms the data successfully it returns `{:ok, output}`,
  where `output` is whatever the given `Babel.Applicable` produces.

  In case of failure an `{:error, Babel.Error.t}` is returned, which contains the failure
  `reason` and a `Babel.Trace` that describes each transformation step. See `Babel.Trace` for details.
  """
  @spec apply(t(output), data) :: {:ok, output} | {:error, Error.t()} when output: any
  def apply(babel, data) do
    trace = trace(babel, data)

    case Trace.result(trace) do
      {:ok, value} -> {:ok, value}
      {:error, _} -> {:error, Error.new(trace)}
    end
  end

  @doc """
  Tries to transform the given `data` as described by the given `Babel.Applicable`.

  If the `Babel.Applicable` transforms the data successfully it returns `output`,
  where `output` is whatever the given `Babel.Applicable` produces.

  In case of failure a `Babel.Error.t` is raised, whose message includes a `Babel.Trace`
  that describes each transformation step. See `Babel.Trace` for details.
  """
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
  defdelegate at(path), to: __MODULE__, as: :fetch

  @doc "Alias for `fetch/2`."
  @spec at(t, path) :: t
  defdelegate at(babel, path), to: __MODULE__, as: :fetch

  @doc "Begin a new (empty) `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name, [])

  @doc "Equivalent to `call(module, function_name, [])`."
  @spec call(module, function_name :: atom) :: t
  defdelegate call(module, function_name), to: Builtin.Call, as: :new

  @doc "See `call/4`."
  @spec call(t, module, function_name :: atom) :: t
  def call(babel, module, function_name) when is_babel(babel) do
    chain(babel, call(module, function_name))
  end

  @spec call(module, function_name :: atom, extra_args :: list) :: t
  defdelegate call(module, function_name, extra_args), to: Builtin.Call, as: :new

  @doc """
  Calls the specified function with the data as the first argument and the given
  list as additional arguments.

  If you want to pass the data not as the first argument use `then/1` instead.

  #{supports_composition}

  ## Examples

      iex> step = Babel.call(String, :trim, ["="])
      iex> Babel.apply!(step, "= some string =")
      " some string "

      iex> pipeline = Babel.fetch("string") |> Babel.call(String, :trim, ["="])
      iex> Babel.apply!(pipeline, %{"string" => "= some string ="})
      " some string "
  """
  @spec call(t, module, function_name :: atom, extra_args :: list) :: t
  def call(babel, module, function_name, extra_args) do
    chain(babel, call(module, function_name, extra_args))
  end

  @doc "See `cast/2`."
  @spec cast(:boolean) :: t(boolean)
  @spec cast(:integer) :: t(integer)
  @spec cast(:float) :: t(float)
  defdelegate cast(type), to: Builtin.Cast, as: :new

  @doc """
  Casts the data to the a boolean, float, or integer.

  To cast data to a different type use either `call/2` or `then/1`.

  #{supports_composition}

  ## Examples

      iex> step = Babel.cast(:boolean)
      iex> Babel.apply!(step, "true")
      true
      iex> Babel.apply!(step, "FALSE")
      false
      iex> Babel.apply!(step, " YeS  ")
      true
      iex> Babel.apply!(step, "   no")
      false

      iex> step = Babel.cast(:integer)
      iex> Babel.apply!(step, "42")
      42
      iex> Babel.apply!(step, 42.6)
      42
      iex> Babel.apply!(step, "  42.6 ")
      42

      iex> step = Babel.cast(:float)
      iex> Babel.apply!(step, "42")
      42.0
      iex> Babel.apply!(step, 42)
      42.0
      iex> Babel.apply!(step, "  42.6 ")
      42.6

      iex> pipeline = Babel.fetch("boolean") |> Babel.cast(:boolean)
      iex> Babel.apply!(pipeline, %{"boolean" => " True "})
      true
  """
  @spec cast(t(), :boolean) :: t(boolean)
  @spec cast(t(), :integer) :: t(integer)
  @spec cast(t(), :float) :: t(float)
  def cast(babel, target) do
    chain(babel, cast(target))
  end

  @doc """
  Combines two steps into a `Babel.Pipeline`.

  All steps in a pipeline are evaluated sequentially, an error stops the pipeline,
  unless an `on_error` handler has been set.
  """
  @spec chain(nil, next) :: next when next: t
  def chain(nil, next), do: next

  @spec chain(t(input, in_between), next :: t(in_between, output)) :: Pipeline.t(input, output)
        when input: any, in_between: any, output: any
  def chain(babel, next) do
    babel
    |> Pipeline.new()
    |> Pipeline.chain(next)
  end

  @doc """
  Always returns the given value, regardless of what data is passed in.

  Useful in combination with `match/1` or `flat_map/1`.

  #{supports_composition}

  ## Examples

      iex> step = Babel.const(:my_cool_value)
      iex> Babel.apply!(step, "does not matter")
      :my_cool_value

      iex> step = Babel.const(42)
      iex> Babel.apply!(step, "does not matter")
      42
  """
  @spec const(value) :: t(value) when value: any
  defdelegate const(value), to: Builtin.Const, as: :new

  @doc "Alias for `match/1`."
  @spec choose((input -> t(input, output))) :: t(output) when input: data, output: term
  defdelegate choose(chooser), to: __MODULE__, as: :match

  @doc "Alias for `match/2`."
  @spec choose(t(), (input -> t(input, output))) :: t(output)
        when input: data, output: term
  defdelegate choose(babel, chooser), to: __MODULE__, as: :match

  @doc """
  Always errors with the given reason. Useful in combination with `match/1` or `flat_map/1`.

  ## Examples

      iex> step = Babel.fail(:my_cool_reason)
      iex> {:error, babel_error} = Babel.apply(step, "does not matter")
      iex> babel_error.reason
      :my_cool_reason
  """
  @spec fail(reason_or_function :: reason | (input -> reason)) :: t(no_return)
        when input: any, reason: any
  defdelegate fail(reason_or_function), to: Builtin.Fail, as: :new

  @doc """
  Fetches the given path from the data, erroring when it cannot be found.

  Use `get/2` to recover to a default.

  #{supports_composition}

  ## Examples

      iex> step = Babel.fetch(:some_key)
      iex> Babel.apply!(step, %{some_key: "some value"})
      "some value"

      iex> step = Babel.fetch([:some_key, "nested key", 2])
      iex> Babel.apply!(step, %{some_key: %{"nested key" => [:first, :second, :third, :fourth]}})
      :third

      iex> pipeline = Babel.fetch(:some_key) |> Babel.fetch("nested key") |> Babel.fetch(-1)
      iex> Babel.apply!(pipeline, %{some_key: %{"nested key" => [:first, :second, :third, :fourth]}})
      :fourth
  """
  @spec fetch(path) :: t
  defdelegate fetch(path), to: Builtin.Fetch, as: :new

  @spec fetch(t(), path) :: t
  def fetch(babel, path) do
    chain(babel, fetch(path))
  end

  @doc "See `flat_map/2`."
  @spec flat_map((input -> t(input, output))) :: t([output])
        when input: data, output: term
  defdelegate flat_map(mapper), to: Builtin.FlatMap, as: :new

  @doc """
  Applies the `Babel.Applicable` returned by the given function to each element of an `Enumerable`,
  effectively allowing you to make a choice.

  Functionally equivalent to `Babel.map(Babel.match(fn ... end))`.

  Use `map/1` if you want to apply the same applicable to all.

  #{supports_composition}

  ## Examples

      iex> step = Babel.flat_map(fn
      ...>   map when is_map(map) -> Babel.fetch(:some_key)
      ...>   _ -> Babel.const(:default_value)
      ...> end)
      iex> Babel.apply!(step, [%{some_key: "some value"}, [not_a: "map"]])
      ["some value", :default_value]

      iex> pipeline = Babel.fetch("list") |> Babel.flat_map(fn
      ...>   map when is_map(map) -> Babel.fetch(:some_key)
      ...>   _ -> Babel.const(:default_value)
      ...> end)
      iex> Babel.apply!(pipeline, %{"list" => [%{some_key: "some value"}, [not_a: "map"]]})
      ["some value", :default_value]
  """
  @spec flat_map(t(Enumerable.t(input)), (input -> t(input, output))) :: t([output])
        when input: data, output: term
  def flat_map(babel, mapper) do
    chain(babel, flat_map(mapper))
  end

  @doc "Equivalent to `get(path, nil)`."
  @spec get(path) :: t
  defdelegate get(path), to: Builtin.Get, as: :new

  @doc "See `get/3`."
  @spec get(path, default :: any) :: t
  defdelegate get(path, default), to: Builtin.Get, as: :new

  @doc """
  Fetches the given path from the data, returning the given default when it cannot be found.

  #{supports_composition}

  ## Examples

      iex> step = Babel.get(:some_key, :my_default)
      iex> Babel.apply!(step, %{some_key: "some value"})
      "some value"

      iex> step = Babel.get(:some_key, :my_default)
      iex> Babel.apply!(step, %{})
      :my_default

      iex> step = Babel.get([:some_key, "nested key", 2], :my_default)
      iex> Babel.apply!(step, %{some_key: %{"nested key" => [:first, :second, :third, :fourth]}})
      :third

      iex> pipeline = Babel.fetch([:some_key, "nested key"]) |> Babel.get(-1, :my_default)
      iex> Babel.apply!(pipeline, %{some_key: %{"nested key" => [:first, :second, :third, :fourth]}})
      :fourth
  """
  @spec get(t(), path, default :: any) :: t
  def get(babel, path, default) do
    chain(babel, get(path, default))
  end

  @doc """
  Always returns the data it receives, effectively acting as a noop.

  Useful in combination with `match/1` or `flat_map/1`.

  ## Examples

      iex> step = Babel.identity()
      iex> Babel.apply!(step, "some value")
      "some value"

      iex> step = Babel.identity()
      iex> Babel.apply!(step, :another_value)
      :another_value
  """
  @spec identity() :: t(input, input) when input: any
  defdelegate identity, to: Builtin.Identity, as: :new

  @doc "See `into/2`."
  @spec into(intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  defdelegate into(intoable), to: Builtin.Into, as: :new

  @doc """
  Transforms the received data into the given data structure, evaluating any
  `Babel.Applicable` it comes across.

  #{supports_composition}

  ## Examples

      iex> step = Babel.into(%{atom_key: Babel.fetch("string key")})
      iex> Babel.apply!(step, %{"string key" => "some value"})
      %{atom_key: "some value"}

      iex> step = Babel.fetch(:map) |> Babel.into(%{atom_key: Babel.fetch("string key")})
      iex> Babel.apply!(step, %{map: %{"string key" => "some value"}})
      %{atom_key: "some value"}
  """
  @spec into(t(), intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel, intoable) do
    chain(babel, into(intoable))
  end

  @doc "See `map/2`."
  @spec map(t(input, output)) :: t([output]) when input: data, output: term
  defdelegate map(mapper), to: Builtin.Map, as: :new

  @doc """
  Applies the given `Babel.Applicable` to each element of an `Enumerable`.

  Use `flat_map/1` if you need to choose the applicable for each element.

  #{supports_composition}

  ## Examples

      iex> step = Babel.map(Babel.fetch(:some_key))
      iex> Babel.apply!(step, [%{some_key: "value1"}, %{some_key: "value2"}])
      ["value1", "value2"]

      iex> pipeline = Babel.fetch("list") |> Babel.map(Babel.fetch(:some_key))
      iex> Babel.apply!(pipeline, %{"list" => [%{some_key: "value1"}, %{some_key: "value2"}]})
      ["value1", "value2"]
  """
  @spec map(Pipeline.t(Enumerable.t(input)), t(input, output)) :: t([output])
        when input: data, output: term
  def map(babel, mapper) do
    chain(babel, map(mapper))
  end

  @doc "See `match/2`."
  @spec match((input -> t(input, output))) :: t(output) when input: data, output: term
  defdelegate match(chooser), to: Builtin.Match, as: :new

  @doc """
  Applies the `Babel.Applicable` returned by the given function the data,
  effectively allowing you to make a choice.

  Use `then/1` if you just want to apply an arbitrary function.

  #{supports_composition}

  ## Examples

      iex> step = Babel.match(fn
      ...>   map when is_map(map) -> Babel.fetch(:some_key)
      ...>   _ -> Babel.const(:default_value)
      ...> end)
      iex> Babel.apply!(step, %{some_key: "some value"})
      "some value"
      iex> Babel.apply!(step, [not_a: "map"])
      :default_value

      iex> pipeline = Babel.fetch("nested") |> Babel.match(fn
      ...>   map when is_map(map) -> Babel.fetch(:some_key)
      ...>   _ -> Babel.const(:default_value)
      ...> end)
      iex> Babel.apply!(pipeline, %{"nested" => %{some_key: "some value"}})
      "some value"
  """
  @spec match(t(), (input -> t(input, output))) :: t(output)
        when input: data, output: term
  def match(babel, chooser) do
    chain(babel, match(chooser))
  end

  @doc "Alias for `identity/0`."
  @spec noop() :: t(input, input) when input: any
  defdelegate noop, to: __MODULE__, as: :identity

  @doc """
  Sets the `on_error` handler of a `Babel.Pipeline` which gets called with a
  `Babel.Error` when any given step of a pipeline fails.

  Overwrites any previously set `on_error` handler.

  ## Examples

      iex> pipeline = Babel.fetch("some key") |> Babel.cast(:boolean) |> Babel.on_error(fn %Babel.Error{} -> :recover_to_ok_for_example end)
      iex> Babel.apply!(pipeline, %{"some key" => "not a boolean"})
      :recover_to_ok_for_example
  """
  @spec on_error(t(), Pipeline.on_error(output)) :: t(output) when output: any
  def on_error(babel, function) do
    babel
    |> Pipeline.new()
    |> Pipeline.on_error(function)
  end

  @doc """
  Syntactic sugar for building a named `Babel.Pipeline` with an optional `on_error` handler.

  Note: For future versions we'd like to explore built-in pipeline caching,
        so that each pipeline only gets built _once_.

  ## Examples
  ### Without error handling

      Babel.pipeline :my_pipeline do
        Babel.begin()
        |> Babel.fetch(["some", "path"])
        |> Babel.map(Babel.into(%{some_map: Babel.fetch(:some_key)}))
      end

  Which would be equivalent to:

      :my_pipeline
      |> Babel.begin()
      |> Babel.fetch(["some", "path"])
      |> Babel.map(Babel.into(%{some_map: Babel.fetch(:some_key)}))

  ### With error handling

      Babel.pipeline :my_pipeline do
        Babel.begin()
        |> Babel.fetch(["some", "path"])
        |> Babel.map(Babel.into(%{some_map: Babel.fetch(:some_key)}))
      else
        %Babel.Error{} = error ->
          # recover here in some way
      end

  Which would be equivalent to:

      :my_pipeline
      |> Babel.begin()
      |> Babel.fetch(["some", "path"])
      |> Babel.map(Babel.into(%{some_map: Babel.fetch(:some_key)}))
      |> Babel.on_error(fn %Babel.Error{} = error ->
          # recover here in some way
      end)
  """
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

  @doc """
  Always returns the original data that was given to `Babel`.

  ## Examples

      iex> step = Babel.root()
      iex> Babel.apply!(step, "some value")
      "some value"

      iex> pipeline = Babel.fetch(:list) |> Babel.map(Babel.into(%{
      ...>   nested_key: Babel.fetch(:key),
      ...>   root_key: Babel.root() |> Babel.fetch(:key)
      ...> }))
      iex> Babel.apply!(pipeline, %{key: "root value", list: [%{key: "nested value1"}, %{key: "nested value2"}]})
      [
        %{nested_key: "nested value1", root_key: "root value"},
        %{nested_key: "nested value2", root_key: "root value"}
      ]
  """
  @spec root() :: t()
  defdelegate root, to: Builtin.Root, as: :new

  @doc "See `then/3`."
  @spec then((input -> Step.result_or_trace(output))) :: t(output)
        when input: any, output: any
  defdelegate then(function), to: Builtin.Then, as: :new

  @doc "See `then/3`."
  @spec then(t(input), (input -> Step.result_or_trace(output))) :: t(output)
        when input: data, output: term
  def then(babel, function) when is_babel(babel) do
    chain(babel, then(function))
  end

  @spec then(name, (input -> Step.result_or_trace(output))) :: t(output)
        when input: any, output: any
  defdelegate then(descriptive_name, function), to: Builtin.Then, as: :new

  @doc """
  Applies the given function to the data, basically "do whatever".

  #{supports_composition}

  ## Examples

      iex> step = Babel.then(fn _ -> :haha_you_cant_stop_me_from_ignoring_the_input end)
      iex> Babel.apply!(step, %{some_key: "some value"})
      :haha_you_cant_stop_me_from_ignoring_the_input

      iex> step = Babel.then(fn iso8601 ->
      ...>   with {:ok, datetime, _offset} <- DateTime.from_iso8601(iso8601) do
      ...>     {:ok, datetime}
      ...>   end
      ...> end)
      iex> Babel.apply!(step, "2015-01-23T23:50:07Z")
      ~U[2015-01-23 23:50:07Z]

      iex> pipeline = Babel.fetch("datetime") |> Babel.then(fn iso8601 ->
      ...>   with {:ok, datetime, _offset} <- DateTime.from_iso8601(iso8601) do
      ...>     {:ok, datetime}
      ...>   end
      ...> end)
      iex> Babel.apply!(pipeline, %{"datetime" => "2015-01-23T23:50:07Z"})
      ~U[2015-01-23 23:50:07Z]
  """
  @spec then(t(input), name, (input -> Step.result_or_trace(output))) :: t(output)
        when input: data, output: term
  def then(babel, descriptive_name, function) when is_babel(babel) do
    chain(babel, then(descriptive_name, function))
  end

  @doc "Like `apply/2` but returns a `Babel.Trace` instead."
  @spec trace(t(input, output), data) :: Trace.t(input, output) when input: any, output: any
  def trace(babel, data) do
    Babel.Applicable.apply(babel, Babel.Context.new(data))
  end

  @doc "Like `try/2` but returns the accumulated failure when all steps fail."
  @spec try(applicables :: nonempty_list(t(output))) :: t(output)
        when output: any
  defdelegate try(applicables), to: Builtin.Try, as: :new

  @doc "See `try/3`."
  @spec try(t(input), applicables :: nonempty_list(t(input, output))) :: t(input, output)
        when input: any, output: any
  def try(babel, applicables) when is_babel(babel) do
    chain(babel, __MODULE__.try(applicables))
  end

  @spec try(applicables :: t(output) | nonempty_list(t(output)), default) :: t(output | default)
        when output: any, default: any
  defdelegate try(applicables, default), to: Builtin.Try, as: :new

  @doc """
  Returns the result of the first `Babel.Applicable` that succeeds.

  If none succeed it either returns the given default or an accumulated error.

  #{supports_composition}

  ## Examples

      iex> step = Babel.try([Babel.fetch(:atom_key), Babel.fetch("string key")])
      iex> Babel.apply!(step, %{atom_key: "some value"})
      "some value"

      iex> step = Babel.try([Babel.fetch(:atom_key), Babel.fetch("string key")])
      iex> Babel.apply!(step, %{"string key" => "some value"})
      "some value"

      iex> step = Babel.try([Babel.fetch(:atom_key), Babel.fetch("string key")])
      iex> {:error, babel_error} = Babel.apply(step, %{})
      iex> babel_error.reason
      [{:not_found, :atom_key}, {:not_found, "string key"}]

      iex> step = Babel.try([Babel.fetch(:atom_key), Babel.fetch("string key")], :default_value)
      iex> Babel.apply!(step, %{})
      :default_value

      iex> pipeline = Babel.fetch("map") |> Babel.try([Babel.fetch(:atom_key), Babel.fetch("string key")], :default_value)
      iex> Babel.apply!(pipeline, %{"map" => %{}})
      :default_value
  """
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
