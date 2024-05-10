defmodule Babel.Builtin.ConstTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Const

  describe "new/1" do
    test "returns the step with the given value contained" do
      value = make_ref()

      assert Const.new(value) == %Const{value: value}
    end
  end

  describe "apply/2" do
    test "always returns the value given upon creation" do
      value = make_ref()
      step = Const.new(value)

      assert apply!(step, %{value: make_ref()}) == value
      assert apply!(step, value: make_ref()) == value
      assert apply!(step, {"value", make_ref()}) == value
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      ref = make_ref()
      function = fn _ -> ref end

      step_and_inspect = [
        {Const.new(:value), "Babel.const(:value)"},
        {Const.new("foobar"), "Babel.const(\"foobar\")"},
        {Const.new(ref), "Babel.const(#{inspect(ref)})"},
        {Const.new(function), "Babel.const(#{inspect(function)})"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
