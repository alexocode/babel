defmodule Babel.BuiltinTest do
  use ExUnit.Case, async: true

  import Kernel, except: [apply: 2]

  alias Babel.Builtin
  alias Babel.Step
  alias Babel.Trace

  require Babel.Builtin
  require NaiveDateTime

  @moduletag :skip

  doctest Babel.Builtin

  describe "is_builtin/1" do
    test "returns true for all core steps" do
      core_steps = [
        Builtin.call(List, :to_string, []),
        Builtin.cast(:boolean),
        Builtin.cast(:float),
        Builtin.cast(:integer),
        Builtin.const(:stuff),
        Builtin.fail(:some_reason),
        Builtin.fetch("path"),
        Builtin.flat_map(fn _ -> Builtin.identity() end),
        Builtin.get("path", :default),
        Builtin.identity(),
        Builtin.into(%{}),
        Builtin.map(Builtin.identity()),
        Builtin.match(fn _ -> Builtin.identity() end),
        Builtin.then(:some_name, fn _ -> :value end),
        Builtin.try([Babel.fail(:foobar), Babel.const(:baz)])
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

  defp apply(step, data) do
    {_traces, result} = Step.apply(step, data)
    result
  end

  defp apply!(step, data) do
    {:ok, value} = apply(step, data)
    value
  end
end
