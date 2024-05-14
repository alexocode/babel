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
      data = %{value: %{nested: "nope"}}

      step = Get.new([:value, "nested"], default)
      assert apply!(step, data) == default

      step = Get.new("nested", default)
      assert apply!(step, data) == default
    end

    test "returns an error when trying to fetch an atom or string path from a tuple" do
      paths = [
        :atom,
        "string",
        [:atom, "string"],
        make_ref(),
        self()
      ]

      for path <- paths do
        step = Get.new(path)
        failing_path = path |> List.wrap() |> List.first()

        assert apply(step, {}) == {:error, {:not_supported, Babel.Fetchable.Tuple, failing_path}}
      end
    end

    test "returns an error when the data type doesn't implement Babel.Fetchable" do
      non_fetchable = [
        :atom,
        "string",
        make_ref(),
        self()
      ]

      for data <- non_fetchable do
        step = Get.new(:key)
        assert apply(step, data) == {:error, {:not_implemented, Babel.Fetchable, data}}

        step = Get.new([:list, :path])
        assert apply(step, data) == {:error, {:not_implemented, Babel.Fetchable, data}}
      end
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
