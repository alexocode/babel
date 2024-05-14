defmodule Babel.Builtin.RootTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Root
  alias Babel.Context

  describe "new/0" do
    test "returns the (empty) step" do
      assert Root.new() == %Root{}
    end
  end

  describe "apply/2" do
    test "returns `data` when the given `Babel.Context` has an empty `history`" do
      step = Root.new()
      context = Context.new(make_ref())

      assert Root.apply(step, context) == context.data
    end

    test "returns the `input` of the oldest `Babel.Trace` in the given `Babel.Context.history`" do
      step = Root.new()

      context = %Context{
        history: [
          Babel.trace(Babel.identity(), :input3),
          Babel.trace(Babel.identity(), :input2),
          Babel.trace(Babel.identity(), :input1)
        ]
      }

      assert Root.apply(step, context) == :input1
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      assert inspect(Root.new()) == "Babel.root()"
    end
  end
end
