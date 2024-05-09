defmodule Babel.Builtin.CallTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Call

  require NaiveDateTime

  describe "new/3" do
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
end
