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

  defp apply(step, data) do
    {_traces, result} = Step.apply(step, data)
    result
  end

  defp apply!(step, data) do
    {:ok, value} = apply(step, data)
    value
  end
end
