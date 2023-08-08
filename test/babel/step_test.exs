defmodule Babel.StepTest do
  use ExUnit.Case, async: true

  import Babel.Support.StepFactory

  alias Babel.Step

  describe "new/p" do
    test "creates a step with the given name and function" do
      name = {:cool_name, make_ref()}
      function = fn _ -> name end

      assert Step.new(name, function) == %Step{
               name: name,
               function: function
             }
    end
  end

  describe "apply/2" do
    test "calls the step's function with the given data" do
      data = %{
        some: %{
          nested: [
            "values"
          ]
        }
      }

      step = step(fn %{some: %{nested: [value]}} -> {:ok, value} end)

      assert Step.apply(step, data) == {:ok, "values"}
    end

    test "returns {:ok, <value>} when the function only returns a bare value" do
      ref = make_ref()
      step = step(fn _ -> ref end)

      assert Step.apply(step, :ignored) == {:ok, ref}
    end

    test "wraps the error reason in a Babel.Error and includes the data" do
      ref = make_ref()
      step = step(fn _ -> {:error, ref} end)

      assert {:error, error} = Step.apply(step, :ignored)
      assert %Babel.Error{} = error
      assert error.reason == ref
      assert error.data == :ignored
      assert error.context == step
    end
  end
end
