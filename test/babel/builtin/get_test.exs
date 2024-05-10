defmodule Babel.Builtin.GetTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Get

  describe "new/2" do
    test "returns the step with the given path contained" do
      path = ["foo", :bar, 42]

      assert Get.new(path) == %Get{path: path}
    end

    test "returns the step with the given path and default contained" do
      path = ["foo", :bar, 42]
      default = make_ref()

      assert Get.new(path, default) == %Get{path: path, default: default}
    end
  end

  describe "apply/2" do
    test "returns the value at the given path" do
      step = Get.new(:value)
      data = %{value: make_ref()}

      assert apply!(step, data) == data.value

      step = Get.new([:value, :nested])
      data = %{value: %{nested: make_ref()}}

      assert apply!(step, data) == data.value.nested

      step = Get.new([:value, 2, :nested])

      data = %{
        value: [
          %{nested: make_ref()},
          %{nested: make_ref()},
          %{nested: make_ref()},
          %{nested: make_ref()},
          %{nested: make_ref()}
        ]
      }

      assert apply!(step, data) == get_in(data, [:value, Access.at(2), :nested])
    end

    test "returns the given default a key cannot be found" do
      default = make_ref()
      step = Get.new([:value, "nested"], default)
      data = %{value: %{nested: "nope"}}

      assert apply!(step, data) == default
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Get.new(:foo), "Babel.get(:foo)"},
        {Get.new(["foo", :bar]), "Babel.get([\"foo\", :bar])"},
        {Get.new(["foo", :bar], :default), "Babel.get([\"foo\", :bar], :default)"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
