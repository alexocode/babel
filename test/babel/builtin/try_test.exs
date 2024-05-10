defmodule Babel.Babel.TryTest do
  use Babel.Test.StepCase, async: true

  import Babel.Test.Factory

  alias Babel.Builtin.Try

  describe "new/1" do
    test "returns the step with the given applicable contained" do
      applicable = Babel.fail(:broken)

      assert Try.new(applicable) == %Try{applicables: [applicable]}
    end

    test "returns the step with the given applicables contained" do
      applicables = [
        Babel.fail(:broken),
        Babel.const(make_ref())
      ]

      assert Try.new(applicables) == %Try{applicables: applicables}
    end

    test "returns the step with the given applicables and default contained" do
      applicables = [
        Babel.fail(:broken),
        Babel.const(make_ref())
      ]

      default = make_ref()

      assert Try.new(applicables, default) == %Try{applicables: applicables, default: default}
    end

    test "raises an ArgumentError when passing something that's not a list of applicables" do
      non_applicables = [
        :atom,
        "string",
        %{map: "!"},
        [:list],
        [Babel.identity(), %{}]
      ]

      for invalid <- non_applicables do
        assert_raise ArgumentError, "not a list of Babel.Applicable: #{inspect(invalid)}", fn ->
          Try.new(invalid)
        end
      end
    end
  end

  describe "apply/2" do
    test "returns the result from the first succeeding applicable" do
      data = %{some: %{nested: "map"}}

      step = Try.new(Babel.const(42))
      assert apply!(step, data) == 42

      step = Try.new([Babel.fail(:some_error), Babel.const(42)])
      assert apply!(step, data) == 42

      step = Try.new([Babel.fail(:some_error), Babel.const(42)])
      assert apply!(step, data) == 42

      step = Try.new([Babel.fail(:some_error), Babel.const(42), Babel.const(21)])
      assert apply!(step, data) == 42
    end

    test "returns the given default value when all steps fail" do
      default = make_ref()

      step =
        Try.new(
          [
            Babel.fail(:some_error),
            Babel.fail(:another_error),
            Babel.fail(:third_error)
          ],
          default
        )

      assert apply!(step, nil) == default
    end

    test "returns the accumulated errors of all failing applicables if none succeed" do
      step =
        Try.new([
          Babel.fail(:some_error),
          Babel.fail(:another_error),
          Babel.fail(:third_error)
        ])

      assert {:error, reason} = apply(step, nil)

      assert reason == [
               :some_error,
               :another_error,
               :third_error
             ]
    end

    test "builds a proper trace with nested traces regardless of success or failure" do
      step1 = Babel.fail(:some_error)
      step2 = Babel.fail(:another_error)
      step3 = Babel.identity()
      try_step = Try.new([step1, step2, step3], :default)

      data = {:ok, 42}
      assert %Babel.Trace{} = trace = trace(try_step, data)
      assert trace.babel == try_step
      assert trace.input == data

      assert trace.nested == [
               trace(step1, data),
               trace(step2, data),
               trace(step3, data)
             ]

      data = {:error, :random_reason}
      assert %Babel.Trace{} = trace = trace(try_step, data)
      assert trace.babel == try_step
      assert trace.input == data

      assert trace.nested == [
               trace(step1, data),
               trace(step2, data),
               trace(step3, data)
             ]
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Try.new([Babel.fail(:broken), Babel.const(:value)]),
         "Babel.try([Babel.fail(:broken), Babel.const(:value)])"},
        {Try.new([Babel.fail(:broken), Babel.const(:value)], :my_default),
         "Babel.try([Babel.fail(:broken), Babel.const(:value)], :my_default)"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
