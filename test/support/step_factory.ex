defmodule Babel.Support.StepFactory do
  alias Babel.Step

  def step do
    step({:test, make_ref()})
  end

  def step(function) when is_function(function, 1) do
    step({:test, make_ref()}, function)
  end

  def step(name) do
    # To make the step functions different
    ref = make_ref()

    step(name, fn _ -> {name, ref} end)
  end

  def step(name, function) do
    %Step{
      name: name,
      function: function
    }
  end
end
