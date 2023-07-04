defmodule Babel do
  alias Babel.{Pipeline, Step}

  @type t :: Babel.Pipeline.t() | Babel.Step.t()
  @type data :: Babel.Fetchable.t()

  @typedoc "Any term that describes a Babel operation (like a pipeline or step)"
  @type name :: any

  @spec apply(Babel.Applicable.t(input, output), input) ::
          {:ok, output} | {:error, Babel.Error.t()}
        when input: Babel.data(), output: any
  def apply(babel, data) do
    Babel.Applicable.apply(babel, data)
  end

  @doc "Begin a new `Babel.Pipeline`."
  @spec begin(name) :: Pipeline.t()
  def begin(name), do: Pipeline.new(name)

  def at(babel, name \\ nil, path) do
    chain(babel, Step.Builder.at(name, path))
  end

  def cast(babel, name \\ nil, target) do
    chain(babel, Step.Builder.cast(name, target))
  end

  def chain(%Pipeline{} = pipeline, next) do
    Pipeline.chain(pipeline, next)
  end

  def chain(%Step{} = step, next) do
    pipeline = Pipeline.new(nil, [step])

    chain(pipeline, next)
  end

  def into(babel, name \\ nil, intoable) do
    chain(babel, Step.Builder.into(name, intoable))
  end

  @spec map(t, name, (input -> output)) :: Pipeline.t([output])
        when input: data, output: term
  def map(babel, name \\ nil, mapper) do
    chain(babel, Step.Builder.map(name, mapper))
  end

  @spec flat_map(t, name, mapper :: (input -> Step.t(input, output))) :: Pipeline.t([output])
        when input: data, output: term
  def flat_map(babel, name \\ nil, mapper) do
    chain(babel, Step.Builder.flat_map(name, mapper))
  end

  # @spec apply(t, data) :: {:ok, output} | {:error, Babel.Error.t()} when output: any
  def apply!(_babel, _data) do
    # babel.last_step
    # |> Enum.reverse()
    # |> Enum.reduce_while({:ok, data}, fn step, {:ok, data} ->
    #   case Babel.Step.apply_one(step, data) do
    #     {:ok, value} ->
    #       {:cont, {:ok, value}}

    #     {:error, error} ->
    #       {:halt, {:error, error}}
    #   end
    # end)
  end

  # @spec apply(t(), data) :: {:ok, any}
  # def apply(%Babel{} = babel, data) do
  #   babel.reversed_steps
  #   |> Enum.reverse()
  #   |> Enum.reduce_while({:ok, data}, fn step, {:ok, next} ->
  #     case Babel.Step.apply(step, next) do
  #       {:ok, value} ->
  #         {:cont, {:ok, value}}

  #       {:error, details} ->
  #         {:halt, {:error, details}}
  #     end
  #   end)
  # end
end
