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
      assert error.step == step
    end
  end

  describe "chain/1" do
    test "returns a step whose name is a combination of the given steps" do
      step1 = step()
      step2 = step()
      step3 = step()

      chained_step = Step.chain([step1, step2, step3])

      assert chained_step.name == {:chain, [step1.name, step2.name, step3.name]}
    end

    test "returns a step which applies all given steps when applied" do
      data = %{
        some: %{
          nested: [
            "values"
          ]
        }
      }

      step1 = step(fn %{some: some} -> some end)
      step2 = step(fn %{nested: nested} -> nested end)
      step3 = step(fn [value] -> value end)

      chained_step = Step.chain([step1, step2, step3])

      assert Step.apply(chained_step, data) == {:ok, "values"}
    end
  end
end
