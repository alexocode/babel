defmodule Babel.Test.Factory do
  alias Babel.Step

  def data(extras \\ []) do
    Enum.into(extras, %{value: make_ref()})
  end

  def pipeline(attrs \\ []) do
    Babel.Pipeline.new(
      Keyword.get_lazy(attrs, :name, fn -> {:test, make_ref()} end),
      Keyword.get_lazy(attrs, :on_error, fn ->
        ref = make_ref()
        fn _ -> {:on_error, ref} end
      end),
      Keyword.get_lazy(attrs, :steps, fn -> [step()] end)
    )
  end

  def step do
    step(&Function.identity/1)
  end

  def step(name \\ {:test, make_ref()}, function) do
    Step.new(name, function)
  end
end
