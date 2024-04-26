defmodule Babel do
  import Kernel, except: [apply: 2]

  alias Babel.{Pipeline, Step}

  @type t :: pipeline() | step()
  @type t(output) :: pipeline(output) | step(output)
  @type t(input, output) :: pipeline(input, output) | step(input, output)

  @type pipeline() :: pipeline(term)
  @type pipeline(output) :: Babel.Pipeline.t(output)
  @type pipeline(input, output) :: Babel.Pipeline.t(input, output)

  @type step :: Babel.Step.t()
  @type step(output) :: Babel.Step.t(output)
  @type step(input, output) :: Babel.Step.t(input, output)

  @type applicable(input, output) :: Babel.Applicable.t(input, output)

  @type result(type) :: Babel.Step.result(type)

  @type data :: term

  @typedoc "Any term that describes a Babel operation (like a pipeline or step)"
  @type name :: term

  @typedoc "A term or list of terms describing like in `get_in/2`"
  @type path :: term | list(term)

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name)

  @doc "Alias for `fetch/3`."
  @spec at(t | nil, path) :: t
  def at(babel \\ nil, path), do: fetch(babel, path)

  @spec fetch(t | nil, path) :: t
  def fetch(babel \\ nil, path) do
    chain(babel, Step.Builder.fetch(path))
  end

  @spec get(t | nil, path) :: t
  def get(babel \\ nil, path, default) do
    chain(babel, Step.Builder.get(path, default))
  end

  @spec cast(t | nil, :boolean) :: t(boolean)
  @spec cast(t | nil, :integer) :: t(integer)
  @spec cast(t | nil, :float) :: t(float)
  def cast(babel \\ nil, target) do
    chain(babel, Step.Builder.cast(target))
  end

  @spec into(t | nil, intoable) :: t(intoable) when intoable: Babel.Intoable.t()
  def into(babel \\ nil, intoable) do
    chain(babel, Step.Builder.into(intoable))
  end

  @spec map(t(Enumerable.t(input)) | nil, applicable(input, output)) :: t([output])
        when input: data, output: term
  def map(babel \\ nil, mapper) do
    chain(babel, Step.Builder.map(mapper))
  end

  @spec flat_map(t(Enumerable.t(input)) | nil, (input -> applicable(input, output))) ::
          t([output])
        when input: data, output: term
  def flat_map(babel \\ nil, mapper) do
    chain(babel, Step.Builder.flat_map(mapper))
  end

  @spec choice(t(input) | nil, (input -> applicable(input, output))) :: t(output)
        when input: data, output: term
  def choice(babel \\ nil, chooser) do
    chain(babel, Step.Builder.choice(chooser))
  end

  @spec then(t(input) | nil, name, Step.step_fun(input, output)) :: t(output)
        when input: data, output: term
  def then(babel \\ nil, name \\ nil, function) do
    chain(babel, Step.new(name, function))
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
