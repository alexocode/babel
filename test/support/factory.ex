defmodule Babel.Test.Factory do
  @moduledoc false
  require Babel

  def context(data \\ data()) do
    Babel.Context.new(data)
  end

  def data(extras \\ []) do
    Enum.into(extras, %{value: make_ref()})
  end

  def pipeline(attrs \\ [])

  def pipeline([babel | _] = steps) when Babel.is_babel(babel) do
    pipeline(steps: steps)
  end

  def pipeline(attrs) when is_list(attrs) do
    Babel.Pipeline.new(
      Keyword.get_lazy(attrs, :name, fn -> {:test, make_ref()} end),
      Keyword.get_lazy(attrs, :on_error, fn ->
        ref = make_ref()
        fn _ -> {:on_error, ref} end
      end),
      Keyword.get_lazy(attrs, :steps, fn -> [step()] end)
    )
  end

  def step, do: step(make_ref())

  def step(function) when is_function(function, 1) do
    Babel.Builtin.Then.new(function)
  end

  def step(value) do
    Babel.Builtin.Const.new(value)
  end

  def trace(attrs \\ []) do
    Babel.Trace.new(
      Keyword.get_lazy(attrs, :babel, fn -> step() end),
      Keyword.get_lazy(attrs, :input, fn -> data() end),
      Keyword.get_lazy(attrs, :output, fn -> data() end),
      Keyword.get_lazy(attrs, :nested, fn -> random_nr_of(fn -> trace(nested: []) end, 0..10) end)
    )
  end

  defp random_nr_of(generator, min..max = range) when min <= max do
    generator
    |> Stream.repeatedly()
    |> Enum.take(Enum.random(range))
  end
end
