defmodule Babel.Step.Builder do
  alias Babel.Step
  alias Babel.Step.Builder.Primitives

  @type path :: term | list(term)
  @type name :: Step.name()

  @spec at(path) :: Step.t(Babel.data())
  @spec at(name, path) :: Step.t(Babel.data())
  def at(name \\ nil, path) do
    path = List.wrap(path)

    Step.new(name || {:at, path}, &Primitives.fetch(&1, path))
  end

  @spec cast(:integer) :: Step.t(Babel.data(), integer)
  @spec cast(:float) :: Step.t(Babel.data(), float)
  @spec cast(:boolean) :: Step.t(Babel.data(), boolean)
  @spec cast(Step.step_fun(input, output)) :: Step.t(input, output) when input: any, output: any
  @spec cast(name, :integer) :: Step.t(Babel.data(), integer)
  @spec cast(name, :float) :: Step.t(Babel.data(), float)
  @spec cast(name, :boolean) :: Step.t(Babel.data(), boolean)
  @spec cast(name, Step.step_fun(input, output)) :: Step.t(input, output)
        when input: any, output: any
  def cast(name \\ nil, type_or_function)

  def cast(name, type) when type in [:boolean, :float, :integer] do
    cast(name || {:cast, type}, &Primitives.cast(type, &1))
  end

  def cast(name, function) when is_function(function, 1) do
    Step.new(name || :cast, function)
  end

  @spec map(mapper :: (input -> output)) :: Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  @spec map(name, mapper :: Step.step_fun(input, output)) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def map(name \\ nil, mapper) do
    name = name || :map

    Step.new(name, fn data ->
      data
      |> Enum.reduce({:ok, []}, fn element, {ok_or_error, list} ->
        {name, element}
        |> Step.new(mapper)
        # TODO: Invoke a returned step
        |> Step.apply(element)
        |> case do
          {^ok_or_error, value} ->
            {ok_or_error, [value | list]}

          {:error, error} when ok_or_error == :ok ->
            {:error, [error]}

          {:ok, _value} when ok_or_error == :error ->
            {:error, list}
        end
      end)
      |> then(fn {ok_or_error, list} ->
        {ok_or_error, Enum.reverse(list)}
      end)
    end)
  end
end
