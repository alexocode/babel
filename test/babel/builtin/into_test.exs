defmodule Babel.Builtin.IntoTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Into

  describe "new/1" do
    test "returns the step with the given intoable contained" do
      intoables = [
        %{},
        [],
        {},
        %Into{intoable: []}
      ]

      for intoable <- intoables do
        assert Into.new(intoable) == %Into{intoable: intoable}
      end
    end
  end

  describe "apply/2" do
    test "maps the values into the data structure as expected" do
      data = %{value1: make_ref(), value2: make_ref(), value3: make_ref(), value4: make_ref()}

      step =
        Into.new(%{
          :some_key => Babel.fetch(:value2),
          Babel.fetch(:value1) => :value1
        })

      assert apply!(step, data) == %{
               :some_key => data.value2,
               data.value1 => :value1
             }
    end

    test "returns the collected errors when nested steps fail" do
      step =
        Into.new(%{
          :some_key => Babel.fetch(:value2),
          Babel.fetch(:value1) => :value1
        })

      assert {:error, reason} = apply(step, %{})
      assert reason == [not_found: :value2, not_found: :value1]
    end

    test "collects all nested traces" do
      data = %{value1: make_ref(), value2: make_ref(), value3: make_ref(), value4: make_ref()}

      fetch_value2 = Babel.fetch(:value2)
      fetch_value1 = Babel.fetch(:value1)

      step =
        Into.new(%{
          :some_key => fetch_value2,
          fetch_value1 => :value1
        })

      assert %Babel.Trace{} = trace = trace(step, data)

      assert trace.nested == [
               trace(fetch_value2, data),
               trace(fetch_value1, data)
             ]
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Into.new(%{foo: Babel.fetch(:bar)}), "Babel.into(%{foo: Babel.fetch(:bar)})"},
        {Into.new({:ok, Babel.identity()}), "Babel.into({:ok, Babel.identity()})"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
