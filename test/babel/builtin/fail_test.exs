defmodule Babel.Builtin.FailTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Fail

  describe "new/1" do
    test "returns the step with the given reason contained" do
      reason = {:reason, make_ref()}

      assert Fail.new(reason) == %Fail{reason: reason}
    end
  end

  describe "apply/2" do
    test "always fails with the given reason" do
      reason = {:some_reason, make_ref()}
      step = Fail.new(reason)

      assert apply(step, nil) == {:error, reason}
      assert apply(step, %{}) == {:error, reason}
    end

    test "allows to pass a function to construct the error reason" do
      ref = make_ref()
      step = Fail.new(&{:some_reason, ref, &1})

      assert apply(step, nil) == {:error, {:some_reason, ref, nil}}
      assert apply(step, %{}) == {:error, {:some_reason, ref, %{}}}
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      ref = make_ref()
      function = fn _ -> ref end

      step_and_inspect = [
        {Fail.new(:value), "Babel.fail(:value)"},
        {Fail.new("foobar"), "Babel.fail(\"foobar\")"},
        {Fail.new(ref), "Babel.fail(#{inspect(ref)})"},
        {Fail.new(function), "Babel.fail(#{inspect(function)})"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
