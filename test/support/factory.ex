defmodule Babel.Test.Factory do
  alias Babel.Step

  require Babel

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

  def step(attrs \\ [])

  def step(function) when is_function(function, 1) do
    step(function: function)
  end

  def step(attrs) when is_list(attrs) do
    Step.new(
      Keyword.get_lazy(attrs, :name, fn -> {:test, make_ref()} end),
      Keyword.get(attrs, :function, &Function.identity/1)
    )
  end
end
