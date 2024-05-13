defmodule Babel.Builtin.MatchTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Match

  describe "new/1" do
    test "returns the step with the given matcher contained" do
      matcher = fn _ -> Babel.identity() end

      assert Match.new(matcher) == %Match{matcher: matcher}
    end

    test "raises an ArgumentError when passing something that's not an arity 1 function" do
      non_functions = [
        :atom,
        "string",
        %{map: "!"},
        [:list]
      ]

      for invalid <- non_functions do
        assert_raise ArgumentError, "not an arity 1 function: #{inspect(invalid)}", fn ->
          Match.new(invalid)
        end
      end
    end
  end

  describe "apply/2" do
    test "applies the applicable returned by the given matcher" do
      step =
        Match.new(fn
          1 -> Babel.const(:value1)
          2 -> Babel.const(:value2)
        end)

      assert apply!(step, 1) == :value1
      assert apply!(step, 2) == :value2
    end

    test "builds a proper trace" do
      step =
        Match.new(fn
          1 -> Babel.const(:value1)
          2 -> Babel.const(:value2)
        end)

      assert %Babel.Trace{} = trace = trace(step, 1)
      assert trace.babel == step
      assert trace.input == 1

      assert trace.nested == [
               trace(Babel.const(:value1), 1)
             ]

      assert %Babel.Trace{} = trace = trace(step, 2)
      assert trace.babel == step
      assert trace.input == 2

      assert trace.nested == [
               trace(Babel.const(:value2), 2)
             ]
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      function1 = fn _ -> Babel.identity() end
      function2 = fn _ -> Babel.const(:value) end

      step_and_inspect = [
        {Match.new(function1), "Babel.match(#{inspect(function1)})"},
        {Match.new(function2), "Babel.match(#{inspect(function2)})"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
