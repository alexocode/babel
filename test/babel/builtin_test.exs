defmodule Babel.BuiltinTest do
  use ExUnit.Case, async: true

  alias Babel.Builtin

  require Builtin

  doctest Builtin

  describe "is_builtin/1" do
    test "returns true for all builtin steps" do
      builtin_steps = [
        Babel.call(List, :to_string, []),
        Babel.cast(:boolean),
        Babel.cast(:float),
        Babel.cast(:integer),
        Babel.const(:stuff),
        Babel.fail(:some_reason),
        Babel.fetch("path"),
        Babel.flat_map(fn _ -> Babel.identity() end),
        Babel.get("path", :default),
        Babel.identity(),
        Babel.into(%{}),
        Babel.map(Babel.identity()),
        Babel.match(fn _ -> Babel.identity() end),
        Babel.then(:some_name, fn _ -> :value end),
        Babel.try([Babel.fail(:foobar), Babel.const(:baz)])
      ]

      for step <- builtin_steps do
        assert Builtin.is_builtin(step)
        assert Builtin.builtin?(step)
      end
    end

    test "returns false for a custom step" do
      step = %Babel.Test.EmptyCustomStep{}

      refute Builtin.is_builtin(step)
      refute Builtin.builtin?(step)
    end
  end
end
