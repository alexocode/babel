defmodule Babel.Builtin.FetchTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Fetch

  describe "new/1" do
    test "returns the step with the given path contained" do
      path = ["foo", :bar, 42]

      assert Fetch.new(path) == %Fetch{path: path}
    end
  end

  describe "apply/2" do
    test "returns the value at the given path" do
      step = Fetch.new(:value)
      data = %{value: make_ref()}

      assert apply!(step, data) == data.value

      step = Fetch.new([:value, :nested])
      data = %{value: %{nested: make_ref()}}

      assert apply!(step, data) == data.value.nested

      step = Fetch.new([:value, 2, :nested])

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

    test "returns an error when a key cannot be found" do
      step = Fetch.new([:value, "nested"])
      data = %{value: %{nested: "nope"}}

      assert apply(step, data) == {:error, {:not_found, "nested"}}
    end

    test "returns an error when the data type doesn't implement Babel.Fetchable" do
      step = Fetch.new(:key)

      non_fetchable = [
        :atom,
        "string",
        make_ref(),
        self()
      ]

      for data <- non_fetchable do
        assert apply(step, data) == {:error, {:not_implemented, Babel.Fetchable, data}}
      end
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Fetch.new(:foo), "Babel.fetch(:foo)"},
        {Fetch.new(["foo", :bar]), "Babel.fetch([\"foo\", :bar])"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
