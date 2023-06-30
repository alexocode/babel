defmodule Babel.StepTest do
  use ExUnit.Case, async: true

  alias Babel.Step

  describe "new/1" do
    test "returns a Step with the given function and a depth of 1" do
      function = fn a -> a end

      assert Step.new(function) == %Step{
               depth: 1,
               function: function,
               next: nil
             }
    end
  end

  describe "concat/2" do
    test "when left has no next, puts right there" do
      left = step()
      right = step()
      step = Step.concat(left, right)

      assert %Step{} = step
      assert step.function == left.function
      assert step.next == right
    end

    test "when left has no next, sets it's depth to right's depth plus one" do
      left = step()
      right = step()
      step = Step.concat(left, right)

      assert %Step{} = step
      assert step.function == left.function
      assert step.depth == right.depth + 1
    end

    test "when left has two next steps it attaches right to the last step and adds it's depth to each step" do
      left = step(step(step()))
      right = step()
      step = Step.concat(left, right)

      assert %Step{} = step
      assert step.function == left.function
      assert step.next.next.next == right
      assert step.next.next.depth == right.depth + 1
      assert step.next.depth == right.depth + 2
      assert step.depth == right.depth + 3
    end
  end

  describe "apply/2" do
    test "runs the given data through all steps sequentially and returns the result" do
      data = %{
        some: %{
          nested: [
            "values"
          ]
        }
      }

      step =
        step(
          fn %{some: some} -> some end,
          step(
            fn %{nested: nested} -> nested end,
            step(fn [value | _] -> value end)
          )
        )

      assert Step.apply(step, data) == {:ok, "values"}
    end
  end

  defp step do
    step(nil, nil)
  end

  defp step(function) when is_function(function, 1) do
    step(function, nil)
  end

  defp step(%Step{} = next) do
    step(nil, next)
  end

  defp step(function, next) do
    depth =
      if next do
        next.depth + 1
      else
        1
      end

    # To make the step functions different
    ref = make_ref()
    function = function || fn _ -> ref end

    %Step{
      depth: depth,
      function: function,
      next: next
    }
  end
end
