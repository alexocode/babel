defmodule Babel.Step.Builder do
  alias Babel.Step
  alias Babel.Step.Builder.Primitives

  require Step

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

  @spec flat_map(mapper :: Step.t(input, output) | (input -> Step.t(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  @spec flat_map(name, mapper :: Step.t(input, output) | (input -> Step.t(input, output))) ::
          Step.t(Enumerable.t(input), list(output))
        when input: any, output: any
  def flat_map(name \\ nil, mapper)

  def flat_map(name, mapper) when is_function(mapper, 1) do
    name = name || :flat_map

    Step.new(name, fn data ->
      {ok_or_error, list} =
        Enum.reduce(data, {:ok, []}, fn element, {ok_or_error, list} ->
          %Step{} = mapped_step = mapper.(element)

          mapped_step
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

      {ok_or_error, Enum.reverse(list)}
    end)
  end

  def flat_map(name, %Step{} = mapper) do
    flat_map(
      name || {:flat_map, mapper.name},
      fn _ -> mapper end
    )
  end
end
