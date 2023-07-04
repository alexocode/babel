defmodule Babel do
  import Kernel, except: [apply: 2]

  alias Babel.{Pipeline, Step}

  @type t :: t(term)
  @type t(output) :: t(any, output)
  @type t(input, output) :: Babel.Pipeline.t(input, output) | Babel.Step.t(output)

  @type pipeline() :: pipeline(term)
  @type pipeline(output) :: Babel.Pipeline.t(output)

  @type applicable(input, output) :: Babel.Applicable.t(input, output)

  @type result(type) :: Babel.Step.result(type)

  @type data :: Babel.Fetchable.t()

  @typedoc "Any term that describes a Babel operation (like a pipeline or step)"
  @type name :: any

  @typedoc "A term or list of terms describing like in `get_in/2`"
  @type path :: term | list(term)

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name)

  @doc "Alias for `fetch/3`."
  @spec at(t | nil, name, path) :: t
  def at(babel \\ nil, name \\ nil, path) do
    fetch(babel, name, path)
  end

  @spec fetch(t | nil, name, path) :: t
  def fetch(babel \\ nil, name \\ nil, path) do
    chain(babel, Step.Builder.fetch(name, path))
  end

  @spec get(t | nil, name, path) :: t
  def get(babel \\ nil, name \\ nil, path, default) do
    chain(babel, Step.Builder.get(name, path, default))
  end

  @spec cast(t | nil, name, :boolean) :: t(boolean)
  @spec cast(t | nil, name, :integer) :: t(integer)
  @spec cast(t | nil, name, :float) :: t(float)
  def cast(babel \\ nil, name \\ nil, target) do
    chain(babel, Step.Builder.cast(name, target))
  end

  @spec chain(nil, next) :: next when next: t
  @spec chain(t(input, in_between), next :: t(in_between, output)) :: Pipeline.t(input, output)
        when input: any, in_between: term, output: term
  def chain(nil, next), do: next

  def chain(%Pipeline{} = pipeline, next) do
    Pipeline.chain(pipeline, next)
  end

  def chain(%Step{} = step, next) do
    pipeline = Pipeline.new(nil, [step])

    chain(pipeline, next)
  end

  @spec into(t | nil, name, intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel \\ nil, name \\ nil, intoable) do
    chain(babel, Step.Builder.into(name, intoable))
  end

  @spec map(
          t(Enumerable.t(input)) | nil,
          name,
          applicable(input, output)
        ) :: t([output])
        when input: data, output: term
  def map(babel \\ nil, name \\ nil, mapper) do
    chain(babel, Step.Builder.map(name, mapper))
  end

  @spec flat_map(
          t(Enumerable.t(input)) | nil,
          name,
          (input -> applicable(input, output))
        ) :: t([output])
        when input: data, output: term
  def flat_map(babel \\ nil, name \\ nil, mapper) do
    chain(babel, Step.Builder.flat_map(name, mapper))
  end

  @spec then(
          t(input) | nil,
          name,
          Step.step_fun(input, output)
        ) :: t(output)
        when input: data, output: term
  def then(babel \\ nil, name \\ nil, function) do
    chain(babel, Step.new(name, function))
  end

  @spec apply(Babel.Applicable.t(input, output), input) ::
          {:ok, output} | {:error, Babel.Error.t()}
        when input: Babel.data(), output: any
  def apply(babel, data) do
    Babel.Applicable.apply(babel, data)
  end

  @spec apply!(Babel.Applicable.t(input, output), input) :: output | no_return
        when input: Babel.data(), output: any
  def apply!(babel, data) do
    case apply(babel, data) do
      {:ok, output} ->
        output

      {:error, %Babel.Error{} = error} ->
        raise error
    end
  end
end
