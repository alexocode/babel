defmodule Babel.Step.BuilderTest do
  use ExUnit.Case, async: true

  import Babel.Support.StepFactory

  alias Babel.Step
  alias Babel.Step.Builder

  describe "flat_map/2" do
    test "returns a step with the given name" do
      step = Builder.flat_map(:given_name, step())

      assert step.name == :given_name
    end

    test "returns a step that applies the given step to each element of an enumerable" do
      mapping_step = step(&{:mapped, &1})
      step = Builder.flat_map(mapping_step)

      assert {:ok, mapped} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1},
               {:mapped, 2},
               {:mapped, 3}
             ]
    end

    test "allows to pass a function that returns a step which gets evaluated immediately" do
      mapping_function = fn element -> step(&{:mapped, element, &1}) end
      step = Builder.flat_map(mapping_function)

      assert {:ok, mapped} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1, 1},
               {:mapped, 2, 2},
               {:mapped, 3, 3}
             ]
    end
  end
end
