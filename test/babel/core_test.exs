defmodule Babel.CoreTest do
  use ExUnit.Case, async: true

  import Babel.Support.StepFactory

  alias Babel.Core
  alias Babel.Step

  describe "map/2" do
    test "returns a step that applies the given step to each element of an enumerable" do
      mapping_step = step(&{:mapped, &1})
      step = Core.map(mapping_step)

      assert {_traces, {:ok, mapped}} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1},
               {:mapped, 2},
               {:mapped, 3}
             ]
    end
  end

  describe "flat_map/2" do
    test "allows to pass a function that returns a step which gets evaluated immediately" do
      mapping_function = fn element -> step(&{:mapped, element, &1}) end
      step = Core.flat_map(mapping_function)

      assert {_traces, {:ok, mapped}} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1, 1},
               {:mapped, 2, 2},
               {:mapped, 3, 3}
             ]
    end
  end
end
