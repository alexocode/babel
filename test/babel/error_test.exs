defmodule Babel.ErrorTest do
  use ExUnit.Case, async: true

  import Babel.Test.Factory

  alias Babel.Error

  describe "new/1" do
    test "extracts the reason from the trace and includes it" do
      reason = {:my_cool_reason, make_ref()}
      trace = trace(output: {:error, reason})

      assert Error.new(trace) == %Error{reason: reason, trace: trace}
    end

    test "relies on Babel.Trace.result/1 to determine the reason" do
      trace = trace(output: :error)

      assert Error.new(trace) == %Error{reason: :unknown, trace: trace}
    end
  end

  describe "message/1" do
    test "renders the message as expected" do
      error = {:error, :broken}
      root_cause1 = trace(output: error, nested: [])
      root_cause2 = trace(output: error, nested: [])

      trace =
        trace(
          output: error,
          nested: [
            trace(output: {:ok, :whatever}),
            root_cause1,
            trace(
              output: error,
              nested: [
                trace(output: {:ok, []}),
                root_cause2
              ]
            )
          ]
        )

      error = Error.new(trace)

      assert_message(error, """
      Failed to transform data: :broken

      Root Cause(s):
      1. #{inspect(root_cause1)}
      2. #{inspect(root_cause2)}

      Full Trace:
      #{inspect(trace)}
      """)
    end
  end

  defp assert_message(error, expected) do
    message_lines =
      error
      |> Error.message()
      |> String.split("\n")

    expected_lines = String.split(expected, "\n")

    assert message_lines == expected_lines
  end
end
