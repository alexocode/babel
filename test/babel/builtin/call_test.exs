defmodule Babel.Builtin.CallTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Call

  require NaiveDateTime

  describe "new/3" do
    test "wraps the given module when the specified function exists" do
      assert Call.new(Enum, :to_list) == %Call{module: Enum, function: :to_list, extra_args: []}

      assert Call.new(Map, :fetch, [:some_key]) == %Call{
               module: Map,
               function: :fetch,
               extra_args: [:some_key]
             }
    end

    test "raises an ArgumentError during construction if the given function doesn't exist" do
      assert_raise ArgumentError, "cannot call missing function `DoesNot.exist/1`", fn ->
        Call.new(DoesNot, :exist, [])
      end
    end
  end

  describe "apply/2" do
    test "invokes the expected function" do
      defmodule MyCoolModule do
        def my_cool_function(value, returned) do
          {value, returned}
        end
      end

      returned = make_ref()
      step = Call.new(MyCoolModule, :my_cool_function, [returned])
      data = %{value: make_ref()}

      assert apply!(step, data) == {data, returned}
    end

    test "returns whatever error the function returns" do
      step = Call.new(Map, :fetch, [:something])
      assert {:error, :unknown} = apply(step, %{})

      step = Call.new(NaiveDateTime, :from_iso8601, [])
      assert {:error, :invalid_format} = apply(step, "not a date")

      step = Call.new(Map, :fetch!, [:something])
      assert {:error, %KeyError{key: :something}} = apply(step, %{})
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Call.new(Map, :fetch, [:something]), "Babel.call(Map, :fetch, [:something])"},
        {Call.new(NaiveDateTime, :from_iso8601), "Babel.call(NaiveDateTime, :from_iso8601)"},
        {Call.new(NaiveDateTime, :from_iso8601, []), "Babel.call(NaiveDateTime, :from_iso8601)"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
