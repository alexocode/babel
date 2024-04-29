defmodule Babel.StepTest do
  use ExUnit.Case, async: true

  import Babel.Test.StepFactory

  alias Babel.Step

  describe "new/2" do
    test "creates a step with the given name and function" do
      name = {:cool_name, make_ref()}
      function = fn _ -> name end

      assert Step.new(name, function) == %Step{
               name: name,
               function: function
             }
    end
  end

  describe "apply/2" do
    test "calls the step's function with the given data" do
      data = %{
        some: %{
          nested: [
            "values"
          ]
        }
      }

      step = step(fn %{some: %{nested: [value]}} -> {:ok, value} end)

      assert Step.apply(step, data) == {[], {:ok, "values"}}
    end

    test "returns {:ok, <value>} when the function only returns a bare value" do
      ref = make_ref()
      step = step(fn _ -> ref end)

      assert Step.apply(step, :ignored) == {[], {:ok, ref}}
    end

    test "wraps the error reason in a Babel.Error and includes the data" do
      ref = make_ref()
      step = step(fn _ -> {:error, ref} end)

      assert {[], {:error, error}} = Step.apply(step, :ignored)
      assert error == ref
    end

    test "rescues thrown exceptions and wraps them as reason in a Babel.Error" do
      data = %{ref: make_ref()}
      random_reason = "some reason (#{:rand.uniform(100_000)})"
      step = step(fn _ -> raise random_reason end)

      assert {[], {:error, error}} = Step.apply(step, data)
      assert error == %RuntimeError{message: random_reason}
    end

    test "forwards nested traces" do
      traces = [%Babel.Trace{}]
      step = step(&{traces, &1})
      data = %{value: make_ref()}

      assert Step.apply(step, {:ok, data}) == {traces, {:ok, data}}
      assert Step.apply(step, {:error, data}) == {traces, {:error, data}}
    end

    test "forwards nested traces from a Babel.Error" do
      fail_step = Babel.fail(:some_error)
      step = step(&Babel.apply(fail_step, &1))
      data = %{value: make_ref()}

      assert {traces, {:error, reason}} = Step.apply(step, data)
      assert traces == [%Babel.Trace{babel: fail_step, data: data, result: {:error, :some_error}}]
      assert reason == :some_error
    end
  end
end
