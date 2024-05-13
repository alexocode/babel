defmodule Babel.Builtin.ThenTest do
  use Babel.Test.StepCase, async: true

  import Babel.Test.Factory

  alias Babel.Builtin.Then

  describe "new/1" do
    test "returns the step with the given function contained" do
      function = fn _ -> :some_value end

      assert Then.new(function) == %Then{function: function}
    end

    test "returns the step with the given name and function contained" do
      function = fn _ -> :some_value end

      assert Then.new(:my_name, function) == %Then{name: :my_name, function: function}
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
          Then.new(invalid)
        end
      end
    end
  end

  describe "apply/2" do
    test "invokes the given function" do
      ref = make_ref()
      step = Then.new(&{ref, &1})
      data = %{value: make_ref()}

      assert apply!(step, data) == {ref, data}
    end

    test "captures a nested trace returned by the function" do
      nested_step = Babel.fail(:my_reason)
      step = Then.new(&Babel.trace(nested_step, &1))
      data = data()

      assert %Babel.Trace{} = trace = trace(step, data)
      assert trace.babel == step
      assert trace.input == data
      assert trace.output == apply(nested_step, data)
      assert trace.nested == [trace(nested_step, data)]
    end

    test "captures a nested trace from a Babel.Error" do
      nested_step = Babel.fail(:my_reason)
      step = Then.new(&Babel.apply(nested_step, &1))
      data = data()

      assert %Babel.Trace{} = trace = trace(step, data)
      assert trace.babel == step
      assert trace.input == data
      assert trace.output == apply(nested_step, data)
      assert trace.nested == [trace(nested_step, data)]
    end

    test "captures a nested trace from a raised Babel.Error" do
      nested_step = Babel.fail(:my_reason)
      step = Then.new(&Babel.apply!(nested_step, &1))
      data = data()

      assert %Babel.Trace{} = trace = trace(step, data)
      assert trace.babel == step
      assert trace.input == data
      assert trace.output == apply(nested_step, data)
      assert trace.nested == [trace(nested_step, data)]
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      function1 = fn _ -> :value1 end
      function2 = &Function.identity/1

      step_and_inspect = [
        {Then.new(function1), "Babel.then(#{inspect(function1)})"},
        {Then.new(function2), "Babel.then(#{inspect(function2)})"},
        {Then.new(:id, function2), "Babel.then(:id, #{inspect(function2)})"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
