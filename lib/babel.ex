defmodule Babel do
  import Kernel, except: [apply: 2]

  alias Babel.{Pipeline, Step}

  @type t :: t(term)
  @type t(output) :: t(any, output)
  @type t(input, output) :: Babel.Pipeline.t(input, output) | Babel.Step.t(output)

  @type data :: Babel.Fetchable.t()

  @typedoc "Any term that describes a Babel operation (like a pipeline or step)"
  @type name :: any

  @typedoc "A term or list of terms describing like in `get_in/2`"
  @type path :: term | list(term)

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name \\ nil), do: Pipeline.new(name)

  @spec at(t | nil, name, path) :: t
  def at(babel \\ nil, name \\ nil, path) do
    chain(babel, Step.Builder.at(name, path))
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
          (input -> output)
        ) :: t([output])
        when input: data, output: term
  def map(babel \\ nil, name \\ nil, mapper) do
    chain(babel, Step.Builder.map(name, mapper))
  end

  @spec flat_map(
          t(Enumerable.t(input)) | nil,
          name,
          mapper :: (input -> Step.t(input, output))
        ) :: t([output])
        when input: data, output: term
  def flat_map(babel \\ nil, name \\ nil, mapper) do
    chain(babel, Step.Builder.flat_map(name, mapper))
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
