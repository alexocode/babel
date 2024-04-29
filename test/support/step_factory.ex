defmodule Babel.Test.StepFactory do
  alias Babel.Step

  def step do
    step(&Function.identity/1)
  end

  def step(name \\ {:test, make_ref()}, function) do
    Step.new(name, function)
  end
end
