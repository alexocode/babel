defmodule Babel.TraceTest do
  use ExUnit.Case, async: false

  import Babel.Test.Factory
  import ExUnit.CaptureLog

  alias Babel.Trace

  # doctest Babel.Trace

  describe "new/3" do
    test "returns a Babel.Trace with no nested traces" do
      babel = step()
      input = data()
      output = data()

      assert Trace.new(babel, input, output) == %Trace{
               babel: babel,
               input: input,
               output: output
             }
    end
  end

  describe "new/4" do
    test "returns a Babel.Trace with the given nested traces" do
      babel = step()
      input = data()
      output = data()
      nested = [trace(), trace()]

      assert Trace.new(babel, input, output, nested) == %Trace{
               babel: babel,
               input: input,
               output: output,
               nested: nested
             }
    end
  end

  describe "error?/1" do
    test "returns true when the Trace has an error result" do
      assert Trace.error?(t(:error))
      assert Trace.error?(t({:error, :foo}))
    end

    test "returns false when the Trace has an okish result" do
      refute Trace.error?(t(:ok))
      refute Trace.error?(t({:ok, :foo}))
      refute Trace.error?(t("whatever"))
    end
  end

  describe "ok?/1" do
    test "returns false when the Trace has an okish result" do
      assert Trace.ok?(t(:ok))
      assert Trace.ok?(t({:ok, :foo}))
      assert Trace.ok?(t("whatever"))
    end

    test "returns false when the Trace has an error result" do
      refute Trace.ok?(t(:error))
      refute Trace.ok?(t({:error, :foo}))
    end
  end

  describe "result/1" do
    test "returns a result tuple version of the output, regardless of its shape" do
      assert Trace.result(t({:ok, "some value"})) == {:ok, "some value"}
      assert Trace.result(t("some value")) == {:ok, "some value"}
      assert Trace.result(t(:error)) == {:error, :unknown}
      assert Trace.result(t({:error, :some_reason})) == {:error, :some_reason}
    end
  end

  describe "root_causes/1" do
    test "returns the trace itself when it failed and it has no nested traces" do
      error = {:error, :broken}
      trace = trace(output: error, nested: [])

      assert Trace.root_causes(trace) == [trace]
    end

    test "returns the nested traces which failed and have no nested traces themselves" do
      error = {:error, :broken}

      expected_trace1 = trace(output: error, nested: [])
      expected_trace2 = trace(output: error, nested: [])

      trace =
        trace(
          output: error,
          nested: [
            trace(
              output: error,
              nested: [
                trace(output: {:ok, "some value"}, nested: []),
                trace(output: {:ok, "another value"}, nested: []),
                expected_trace1
              ]
            ),
            trace(output: {:ok, "third value"}),
            trace(
              output: error,
              nested: [
                expected_trace2
              ]
            )
          ]
        )

      assert Trace.root_causes(trace) == [expected_trace1, expected_trace2]
    end

    test "returns no traces at all when its an ok trace" do
      trace =
        trace(
          output: :ok,
          nested: [
            trace(output: {:ok, "whatever"}, nested: []),
            trace(output: {:ok, "foo"}, nested: []),
            trace(output: {:ok, "bar"}, nested: [])
          ]
        )

      assert Trace.root_causes(trace) == []
    end
  end

  describe "find/2" do
    test "accepts an arbitrary function through which the correct traces can be found" do
      expected_trace1 = trace(nested: [])
      expected_trace2 = trace(nested: [])
      expected_trace3 = trace(nested: [])

      trace =
        trace(
          nested: [
            trace(
              nested: [
                expected_trace1,
                expected_trace2,
                trace(
                  nested: [
                    expected_trace3
                  ]
                )
              ]
            )
          ]
        )

      assert Trace.find(trace, &match?(%{nested: []}, &1)) == [
               expected_trace1,
               expected_trace2,
               expected_trace3
             ]
    end

    test "accepts a raw Babel step" do
      step1 = Babel.const(make_ref())
      step2 = Babel.then(fn _ -> make_ref() end)
      expected_trace1 = trace(babel: step1, nested: [])
      expected_trace2 = trace(babel: step2, nested: [])

      trace =
        trace(
          babel: Babel.then(fn _ -> :whatever end),
          nested: [
            trace(babel: Babel.identity(), nested: []),
            trace(babel: Babel.identity(), nested: []),
            expected_trace1,
            trace(babel: Babel.identity(), nested: [expected_trace2])
          ]
        )

      assert Trace.find(trace, step1) == [expected_trace1]
      assert Trace.find(trace, step2) == [expected_trace2]
    end

    test "accepts an atom describing a builtin step" do
      ref1 = make_ref()
      ref2 = make_ref()
      expected_trace1 = trace(babel: Babel.const(ref1), nested: [])
      expected_trace2 = trace(babel: Babel.const(ref2), nested: [])

      trace =
        trace(
          babel: Babel.identity(),
          nested: [
            trace(babel: Babel.identity(), nested: []),
            trace(babel: Babel.identity(), nested: []),
            expected_trace1,
            trace(babel: Babel.identity(), nested: [expected_trace2])
          ]
        )

      assert Trace.find(trace, :const) == [expected_trace1, expected_trace2]
      assert Trace.find(trace, {:const, [ref1]}) == [expected_trace1]
      assert Trace.find(trace, {:const, [ref2]}) == [expected_trace2]
    end

    test "accepts a list of functions or builtin specs" do
      ref1 = make_ref()
      ref2 = make_ref()
      step1 = Babel.const(ref1)
      step2 = Babel.const(ref2)
      expected_trace1 = trace(babel: step1, nested: [])
      expected_trace2 = trace(babel: step2, nested: [])

      trace =
        trace(
          babel: Babel.into(%{}),
          nested: [
            trace(babel: Babel.identity(), nested: []),
            trace(babel: Babel.identity(), nested: []),
            expected_trace1,
            trace(babel: Babel.map(step2), nested: [expected_trace2])
          ]
        )

      assert Trace.find(trace, [:into, :const]) == [expected_trace1, expected_trace2]
      assert Trace.find(trace, [:into, :map, :const]) == [expected_trace2]
      assert Trace.find(trace, into: [%{}], const: [ref2]) == [expected_trace2]
      assert Trace.find(trace, [:into, :map, step1]) == []
      assert Trace.find(trace, [:into, step1]) == [expected_trace1]

      assert Trace.find(trace, [&match?(%{nested: []}, &1), :const]) == [
               expected_trace1,
               expected_trace2
             ]
    end

    test "logs a warning when the given spec resembles a builtin spec but not quite" do
      logs = capture_log(fn -> Trace.find(trace(), {:const, :some_value}) end)

      assert logs =~
               "[Babel] To find a built-in step the second argument of `{:const, :some_value}` needs to be a list (`{:const, [:some_value]}`)."
    end

    test "does not log a warning when the given spec resembles a builtin spec but not quite but something is found" do
      trace = trace(babel: %Babel.Pipeline{name: {:const, :some_value}})

      logs = capture_log(fn -> Trace.find(trace, {:const, :some_value}) end)

      assert logs == ""
    end
  end

  defp t(output), do: trace(output: output)
end
