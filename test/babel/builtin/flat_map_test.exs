defmodule Babel.Builtin.FlatMapTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.FlatMap

  describe "new/1" do
    test "returns the step with the given mapper contained" do
      mapper = fn _ -> Babel.identity() end

      assert FlatMap.new(mapper) == %FlatMap{mapper: mapper}
    end
  end

  describe "apply/2" do
    test "evaluates the babel returned by the given function" do
      mapping_function = fn element -> Babel.then(&{:mapped, element, &1}) end
      step = FlatMap.new(mapping_function)

      assert trace = trace(step, [1, 2, 3])
      assert %Babel.Trace{} = trace
      assert trace.babel == step
      assert trace.input == [1, 2, 3]

      assert trace.output ==
               {:ok,
                [
                  {:mapped, 1, 1},
                  {:mapped, 2, 2},
                  {:mapped, 3, 3}
                ]}
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      function1 = fn _ -> Babel.identity() end
      function2 = fn _ -> Babel.const(:value) end

      step_and_inspect = [
        {FlatMap.new(function1), "Babel.flat_map(#{inspect(function1)})"},
        {FlatMap.new(function2), "Babel.flat_map(#{inspect(function2)})"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
