defmodule Babel.CoreTest do
  use ExUnit.Case, async: true

  import Kernel, except: [apply: 2]

  alias Babel.Core
  alias Babel.Step

  require Babel.Core
  require NaiveDateTime

  describe "is_core/1" do
    test "returns true for all core steps" do
      core_steps = [
        Core.id(),
        Core.const(:stuff),
        Core.fetch("path"),
        Core.get("path", :default),
        Core.cast(:integer),
        Core.cast(:float),
        Core.cast(:boolean),
        Core.into(%{}),
        Core.call(List, :to_string, []),
        Core.then(:some_name, fn _ -> :value end),
        Core.choice(fn _ -> Core.id() end),
        Core.map(Core.id()),
        Core.flat_map(fn _ -> Core.id() end)
      ]

      for step <- core_steps do
        assert Core.is_core(step)
        assert Core.core?(step)
      end
    end

    test "returns false for a custom step" do
      step = Step.new(:some_name, fn _ -> :value end)

      refute Core.is_core(step)
      refute Core.core?(step)
    end
  end

  describe "id/0" do
    test "returns the value it's applied to" do
      step = Core.id()
      data = %{value: make_ref()}

      assert apply!(step, data) == data
    end
  end

  describe "const/1" do
    test "always returns the value given when creating" do
      value = make_ref()
      step = Core.const(value)
      data = %{value: make_ref()}

      assert apply!(step, data) == value
      assert apply!(step, data) == value
    end
  end

  describe "fetch/1" do
    test "returns the value at the given path" do
      step = Core.fetch(:value)
      data = %{value: make_ref()}

      assert apply!(step, data) == data.value

      step = Core.fetch([:value, :nested])
      data = %{value: %{nested: make_ref()}}

      assert apply!(step, data) == data.value.nested

      step = Core.fetch([:value, 2, :nested])

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
      step = Core.fetch([:value, "nested"])
      data = %{value: %{nested: "nope"}}

      assert {:error, {:not_found, "nested"}} = apply(step, data)
    end
  end

  describe "get/2" do
    test "returns the value at the given path" do
      step = Core.get(:value, :default)
      data = %{value: make_ref()}

      assert apply!(step, data) == data.value

      step = Core.get([:value, :nested], :default)
      data = %{value: %{nested: make_ref()}}

      assert apply!(step, data) == data.value.nested

      step = Core.get([:value, 2, :nested], :default)

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
      step = Core.get([:value, "nested"], default)
      data = %{value: %{nested: "nope"}}

      assert apply!(step, data) == default
    end
  end

  describe "cast(:integer)" do
    test "succeeds when the value is an integer" do
      assert apply!(Core.cast(:integer), 1) == 1
      assert apply!(Core.cast(:integer), 42) == 42
      assert apply!(Core.cast(:integer), -100) == -100
    end

    test "succeeds when the value is the string representation of an integer" do
      assert apply!(Core.cast(:integer), "1") == 1
      assert apply!(Core.cast(:integer), "42") == 42
      assert apply!(Core.cast(:integer), "-100") == -100
    end

    test "succeeds when the value is a float" do
      assert apply!(Core.cast(:integer), 1.0) == 1
      assert apply!(Core.cast(:integer), 42.2) == 42
      assert apply!(Core.cast(:integer), -100.8) == -100
    end

    test "fails when the value is a string without an integer" do
      assert {:error, reason} = apply(Core.cast(:integer), "not an integer")
      assert reason == {:invalid, :integer, "not an integer"}
    end
  end

  describe "cast(:float)" do
    test "succeeds when the value is a float" do
      assert apply!(Core.cast(:float), 1.0) == 1.0
      assert apply!(Core.cast(:float), 42.2) == 42.2
      assert apply!(Core.cast(:float), -100.8) == -100.8
    end

    test "succeeds when the value is the string representation of an float" do
      assert apply!(Core.cast(:float), "1") == 1.0
      assert apply!(Core.cast(:float), "1.0") == 1.0
      assert apply!(Core.cast(:float), "42.2") == 42.2
      assert apply!(Core.cast(:float), "-100.8") == -100.8
    end

    test "succeeds when the value is an integer" do
      assert apply!(Core.cast(:float), 1) == 1.0
      assert apply!(Core.cast(:float), 42) == 42.0
      assert apply!(Core.cast(:float), -100) == -100.0
    end

    test "fails when the value is a string without a float" do
      assert {:error, reason} = apply(Core.cast(:float), "not a float")
      assert reason == {:invalid, :float, "not a float"}
    end
  end

  describe "cast(:boolean)" do
    test "succeeds when the value is a boolean" do
      assert apply!(Core.cast(:boolean), true) == true
      assert apply!(Core.cast(:boolean), false) == false
    end

    test "succeeds when the value is the string representation of an boolean" do
      assert apply!(Core.cast(:boolean), "true") == true
      assert apply!(Core.cast(:boolean), "yES") == true
      assert apply!(Core.cast(:boolean), " yes ") == true
      assert apply!(Core.cast(:boolean), "  FALSE") == false
      assert apply!(Core.cast(:boolean), "no") == false
    end

    test "fails when the value is a string without a boolean" do
      assert {:error, reason} = apply(Core.cast(:boolean), "not a boolean")
      assert reason == {:invalid, :boolean, "not a boolean"}

      assert {:error, reason} = apply(Core.cast(:boolean), 1)
      assert reason == {:invalid, :boolean, 1}
    end
  end

  describe "into/1" do
    test "maps the values into the data structure as expected" do
      data = %{value1: make_ref(), value2: make_ref(), value3: make_ref(), value4: make_ref()}

      step =
        Core.into(%{
          :some_key => Core.fetch(:value2),
          Core.fetch(:value1) => :value1
        })

      assert apply!(step, data) == %{
               :some_key => data.value2,
               data.value1 => :value1
             }
    end

    test "returns the collected errors when nested steps fail" do
      step =
        Core.into(%{
          :some_key => Core.fetch(:value2),
          Core.fetch(:value1) => :value1
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
      step = Core.call(MyCoolModule, :my_cool_function, [returned])
      data = %{value: make_ref()}

      assert apply!(step, data) == {data, returned}
    end

    test "returns whatever error the function returns" do
      step = Core.call(Map, :fetch, [:something])
      assert {:error, :unknown} = apply(step, %{})

      step = Core.call(NaiveDateTime, :from_iso8601, [])
      assert {:error, :invalid_format} = apply(step, "not a date")

      step = Core.call(Map, :fetch!, [:something])
      assert {:error, %KeyError{key: :something}} = apply(step, %{})
    end

    test "raises an ArgumentError during construction if the given function doesn't exist" do
      assert_raise ArgumentError, "cannot call missing function `DoesNot.exist/1`", fn ->
        Core.call(DoesNot, :exist, [])
      end
    end
  end

  describe "then/2" do
    test "invokes the given function" do
      ref = make_ref()
      step = Core.then(:custom_name, &{ref, &1})
      data = %{value: make_ref()}

      assert apply!(step, data) == {ref, data}
    end

    test "sets the given name on the created step" do
      ref = make_ref()
      step = Core.then({:my_cool_name, ref}, &Function.identity/1)

      assert step.name == {:then, [{:my_cool_name, ref}, &Function.identity/1]}
    end

    test "omits a nil name from the generated step name" do
      step = Core.then(&Function.identity/1)

      assert step == Core.then(nil, &Function.identity/1)
      assert step.name == {:then, [&Function.identity/1]}
    end
  end

  describe "choice/1" do
    test "choses the expected applicable" do
      step =
        Core.choice(fn
          1 -> Core.const(:value1)
          2 -> Core.const(:value2)
        end)

      assert apply!(step, 1) == :value1
      assert apply!(step, 2) == :value2
    end
  end

  describe "map/2" do
    test "returns a step that applies the given step to each element of an enumerable" do
      mapping_step = Core.then(&{:mapped, &1})
      step = Core.map(mapping_step)

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
      mapping_function = fn element -> Core.then(&{:mapped, element, &1}) end
      step = Core.flat_map(mapping_function)

      assert {_traces, {:ok, mapped}} = Step.apply(step, [1, 2, 3])

      assert mapped == [
               {:mapped, 1, 1},
               {:mapped, 2, 2},
               {:mapped, 3, 3}
             ]
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
