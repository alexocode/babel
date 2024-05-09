defmodule Babel.BuiltinTest do
  use ExUnit.Case, async: true

  import Kernel, except: [apply: 2]

  alias Babel.Builtin
  alias Babel.Step
  alias Babel.Trace

  require Babel.Builtin
  require NaiveDateTime

  doctest Babel.Builtin

  describe "is_builtin/1" do
    test "returns true for all core steps" do
      core_steps = [
        Builtin.identity(),
        Builtin.const(:stuff),
        Builtin.fetch("path"),
        Builtin.get("path", :default),
        Builtin.cast(:integer),
        Builtin.cast(:float),
        Builtin.cast(:boolean),
        Builtin.into(%{}),
        Builtin.call(List, :to_string, []),
        Builtin.match(fn _ -> Builtin.identity() end),
        Builtin.map(Builtin.identity()),
        Builtin.flat_map(fn _ -> Builtin.identity() end),
        Builtin.fail(:some_reason),
        Builtin.try([Babel.fail(:foobar), Babel.const(:baz)]),
        Builtin.then(:some_name, fn _ -> :value end)
      ]

      for step <- core_steps do
        assert Builtin.is_builtin(step)
        assert Builtin.builtin?(step)
      end
    end

    test "returns false for a custom step" do
      step = Step.new(:some_name, fn _ -> :value end)

      refute Builtin.is_builtin(step)
      refute Builtin.builtin?(step)
    end
  end

  describe "id/0" do
    test "returns the value it's applied to" do
      step = Builtin.identity()
      data = %{value: make_ref()}

      assert apply!(step, data) == data
    end
  end

  describe "const/1" do
    test "always returns the value given when creating" do
      value = make_ref()
      step = Builtin.const(value)
      data = %{value: make_ref()}

      assert apply!(step, data) == value
      assert apply!(step, data) == value
    end
  end

  describe "fetch/1" do
    test "returns the value at the given path" do
      step = Builtin.fetch(:value)
      data = %{value: make_ref()}

      assert apply!(step, data) == data.value

      step = Builtin.fetch([:value, :nested])
      data = %{value: %{nested: make_ref()}}

      assert apply!(step, data) == data.value.nested

      step = Builtin.fetch([:value, 2, :nested])

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
      step = Builtin.fetch([:value, "nested"])
      data = %{value: %{nested: "nope"}}

      assert {:error, {:not_found, "nested"}} = apply(step, data)
    end
  end

  describe "get/2" do
    test "returns the value at the given path" do
      step = Builtin.get(:value, :default)
      data = %{value: make_ref()}

      assert apply!(step, data) == data.value

      step = Builtin.get([:value, :nested], :default)
      data = %{value: %{nested: make_ref()}}

      assert apply!(step, data) == data.value.nested

      step = Builtin.get([:value, 2, :nested], :default)

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
      step = Builtin.get([:value, "nested"], default)
      data = %{value: %{nested: "nope"}}

      assert apply!(step, data) == default
    end
  end

  describe "cast(:integer)" do
    test "succeeds when the value is an integer" do
      assert apply!(Builtin.cast(:integer), 1) == 1
      assert apply!(Builtin.cast(:integer), 42) == 42
      assert apply!(Builtin.cast(:integer), -100) == -100
    end

    test "succeeds when the value is the string representation of an integer" do
      assert apply!(Builtin.cast(:integer), "1") == 1
      assert apply!(Builtin.cast(:integer), "42") == 42
      assert apply!(Builtin.cast(:integer), "-100") == -100
    end

    test "succeeds when the value is a float" do
      assert apply!(Builtin.cast(:integer), 1.0) == 1
      assert apply!(Builtin.cast(:integer), 42.2) == 42
      assert apply!(Builtin.cast(:integer), -100.8) == -100
    end

    test "fails when the value is a string without an integer" do
      assert {:error, reason} = apply(Builtin.cast(:integer), "not an integer")
      assert reason == {:invalid, :integer, "not an integer"}
    end
  end

  describe "cast(:float)" do
    test "succeeds when the value is a float" do
      assert apply!(Builtin.cast(:float), 1.0) == 1.0
      assert apply!(Builtin.cast(:float), 42.2) == 42.2
      assert apply!(Builtin.cast(:float), -100.8) == -100.8
    end

    test "succeeds when the value is the string representation of an float" do
      assert apply!(Builtin.cast(:float), "1") == 1.0
      assert apply!(Builtin.cast(:float), "1.0") == 1.0
      assert apply!(Builtin.cast(:float), "42.2") == 42.2
      assert apply!(Builtin.cast(:float), "-100.8") == -100.8
    end

    test "succeeds when the value is an integer" do
      assert apply!(Builtin.cast(:float), 1) == 1.0
      assert apply!(Builtin.cast(:float), 42) == 42.0
      assert apply!(Builtin.cast(:float), -100) == -100.0
    end

    test "fails when the value is a string without a float" do
      assert {:error, reason} = apply(Builtin.cast(:float), "not a float")
      assert reason == {:invalid, :float, "not a float"}
    end
  end

  describe "cast(:boolean)" do
    test "succeeds when the value is a boolean" do
      assert apply!(Builtin.cast(:boolean), true) == true
      assert apply!(Builtin.cast(:boolean), false) == false
    end

    test "succeeds when the value is the string representation of an boolean" do
      assert apply!(Builtin.cast(:boolean), "true") == true
      assert apply!(Builtin.cast(:boolean), "yES") == true
      assert apply!(Builtin.cast(:boolean), " yes ") == true
      assert apply!(Builtin.cast(:boolean), "  FALSE") == false
      assert apply!(Builtin.cast(:boolean), "no") == false
    end

    test "fails when the value is a string without a boolean" do
      assert {:error, reason} = apply(Builtin.cast(:boolean), "not a boolean")
      assert reason == {:invalid, :boolean, "not a boolean"}

      assert {:error, reason} = apply(Builtin.cast(:boolean), 1)
      assert reason == {:invalid, :boolean, 1}
    end
  end

  describe "into/1" do
    test "maps the values into the data structure as expected" do
      data = %{value1: make_ref(), value2: make_ref(), value3: make_ref(), value4: make_ref()}

      step =
        Builtin.into(%{
          :some_key => Builtin.fetch(:value2),
          Builtin.fetch(:value1) => :value1
        })

      assert apply!(step, data) == %{
               :some_key => data.value2,
               data.value1 => :value1
             }
    end

    test "returns the collected errors when nested steps fail" do
      step =
        Builtin.into(%{
          :some_key => Builtin.fetch(:value2),
          Builtin.fetch(:value1) => :value1
        })

      assert {:error, reason} = apply(step, %{})
      assert reason == [not_found: :value2, not_found: :value1]
    end
  end

  describe "call/3" do
    test "invokes the expected function" do
      defmodule MyCoolModule do
        def my_cool_function(value, returned) do
          {value, returned}
        end
      end

      returned = make_ref()
      step = Builtin.call(MyCoolModule, :my_cool_function, [returned])
      data = %{value: make_ref()}

      assert apply!(step, data) == {data, returned}
    end

    test "returns whatever error the function returns" do
      step = Builtin.call(Map, :fetch, [:something])
      assert {:error, :unknown} = apply(step, %{})

      step = Builtin.call(NaiveDateTime, :from_iso8601, [])
      assert {:error, :invalid_format} = apply(step, "not a date")

      step = Builtin.call(Map, :fetch!, [:something])
      assert {:error, %KeyError{key: :something}} = apply(step, %{})
    end

    test "raises an ArgumentError during construction if the given function doesn't exist" do
      assert_raise ArgumentError, "cannot call missing function `DoesNot.exist/1`", fn ->
        Builtin.call(DoesNot, :exist, [])
      end
    end
  end

  describe "match/1" do
    test "uses the expected returned applicable" do
      step =
        Builtin.match(fn
          1 -> Builtin.const(:value1)
          2 -> Builtin.const(:value2)
        end)

      assert apply!(step, 1) == :value1
      assert apply!(step, 2) == :value2
    end
  end

  describe "map/2" do
    test "returns a step that applies the given step to each element of an enumerable" do
      mapping_step = Builtin.then(&{:mapped, &1})
      step = Builtin.map(mapping_step)

      assert {_traces, {:ok, mapped}} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1},
               {:mapped, 2},
               {:mapped, 3}
             ]
    end
  end

  describe "flat_map/2" do
    test "allows to pass a function that returns a step which gets evaluated immediately" do
      mapping_function = fn element -> Builtin.then(&{:mapped, element, &1}) end
      step = Builtin.flat_map(mapping_function)

      assert {_traces, {:ok, mapped}} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1, 1},
               {:mapped, 2, 2},
               {:mapped, 3, 3}
             ]
    end
  end

  describe "fail/1" do
    test "always fails with the given reason" do
      reason = {:some_reason, make_ref()}
      step = Builtin.fail(reason)

      assert apply(step, nil) == {:error, reason}
      assert apply(step, %{}) == {:error, reason}
    end

    test "allows to pass a function to construct the error reason" do
      ref = make_ref()
      step = Builtin.fail(&{:some_reason, ref, &1})

      assert apply(step, nil) == {:error, {:some_reason, ref, nil}}
      assert apply(step, %{}) == {:error, {:some_reason, ref, %{}}}
    end
  end

  describe "try/1" do
    test "returns the result from the first succeeding applicable" do
      data = %{some: %{nested: "map"}}

      step = Builtin.try(Builtin.const(42))
      assert apply!(step, data) == 42

      step = Builtin.try([Builtin.fail(:some_error), Builtin.const(42)])
      assert apply!(step, data) == 42

      step = Builtin.try([Builtin.fail(:some_error), Builtin.const(42)])
      assert apply!(step, data) == 42

      step = Builtin.try([Builtin.fail(:some_error), Builtin.const(42), Builtin.const(21)])
      assert apply!(step, data) == 42
    end

    test "returns the accumulated errors of all failing applicables if none succeed" do
      step =
        Builtin.try([
          Builtin.fail(:some_error),
          Builtin.fail(:another_error),
          Builtin.fail(:third_error)
        ])

      assert {:error, reason} = apply(step, nil)

      assert reason == [
               :some_error,
               :another_error,
               :third_error
             ]
    end

    test "returns the accumulated traces regardless of success or failure" do
      step1 = Builtin.fail(:some_error)
      step2 = Builtin.fail(:another_error)
      step3 = Builtin.identity()
      try_step = Builtin.try([step1, step2, step3])

      data = {:ok, 42}
      assert {traces, data} = Step.apply(try_step, data)

      assert traces == [
               Trace.apply(step1, data),
               Trace.apply(step2, data),
               Trace.apply(step3, data)
             ]

      data = {:error, :random_reason}
      assert {traces, {:error, reasons}} = Step.apply(try_step, data)

      assert traces == [
               Trace.apply(step1, data),
               Trace.apply(step2, data),
               Trace.apply(step3, data)
             ]

      assert reasons == [
               :some_error,
               :another_error,
               :random_reason
             ]
    end
  end

  describe "try/2" do
    test "returns the given default value when all steps fail" do
      fallback = make_ref()

      step =
        Builtin.try(
          [
            Builtin.fail(:some_error),
            Builtin.fail(:another_error),
            Builtin.fail(:third_error)
          ],
          fallback
        )

      assert apply!(step, nil) == fallback
    end
  end

  describe "then/2" do
    test "invokes the given function" do
      ref = make_ref()
      step = Builtin.then(:custom_name, &{ref, &1})
      data = %{value: make_ref()}

      assert apply!(step, data) == {ref, data}
    end

    test "sets the given name on the created step" do
      ref = make_ref()
      step = Builtin.then({:my_cool_name, ref}, &Function.identity/1)

      assert step.name == {:then, [{:my_cool_name, ref}, &Function.identity/1]}
    end

    test "omits a nil name from the generated step name" do
      step = Builtin.then(&Function.identity/1)

      assert step == Builtin.then(nil, &Function.identity/1)
      assert step.name == {:then, [&Function.identity/1]}
    end
  end

  defp apply(step, data) do
    {_traces, result} = Step.apply(step, data)
    result
  end

  defp apply!(step, data) do
    {:ok, value} = apply(step, data)
    value
  end
end
