defmodule Babel.Builtin.IdentityTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Identity

  describe "new/0" do
    test "returns the (empty) step" do
      assert Identity.new() == %Identity{}
    end
  end

  describe "apply/2" do
    test "always returns the received value" do
      step = Identity.new()
      data = make_ref()

      assert apply!(step, data) == data
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      assert inspect(Identity.new()) == "Babel.identity()"
    end
  end
end
