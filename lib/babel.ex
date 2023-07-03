defmodule Babel do
  @type data :: Babel.Fetchable.t()

  @typedoc "Any term that describes a Babel operation (like a pipeline or step)"
  @type name :: any

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
