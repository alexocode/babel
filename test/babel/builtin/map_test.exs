defmodule Babel.Builtin.MapTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Map

  describe "new/1" do
    test "returns the step with the given applicable contained" do
      applicable = Babel.identity()

      assert Map.new(applicable) == %Map{applicable: applicable}
    end

    test "raises an ArgumentError when passing something that doesn't implement Babel.Applicable" do
      non_applicables = [
        :atom,
        "string",
        %{map: "!"},
        [:list]
      ]

      for invalid <- non_applicables do
        assert_raise ArgumentError, "not a Babel.Applicable: #{inspect(invalid)}", fn ->
          Map.new(invalid)
        end
      end
    end
  end

  describe "apply/2" do
    test "applies the contained step to each element of an enumerable" do
      mapping_step = Babel.then(&{:mapped, &1})
      step = Map.new(mapping_step)

      assert apply!(step, [1, 2, 3]) == [
               {:mapped, 1},
               {:mapped, 2},
               {:mapped, 3}
             ]
    end

    test "builds a proper trace" do
      mapping_step = Babel.then(&{:mapped, &1})
      step = Map.new(mapping_step)

      assert %Babel.Trace{} = trace = trace(step, [1, 2, 3])
      assert trace.babel == step
      assert trace.input == [1, 2, 3]

      assert trace.nested == [
               trace(mapping_step, 1),
               trace(mapping_step, 2),
               trace(mapping_step, 3)
             ]
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Map.new(Babel.identity()), "Babel.map(Babel.identity())"},
        {Map.new(Babel.const(:value)), "Babel.map(Babel.const(:value))"},
        {Map.new(Babel.then(&Function.identity/1)), "Babel.map(Babel.then(&Function.identity/1))"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
