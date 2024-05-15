defmodule Babel.BuiltinTest do
  use ExUnit.Case, async: true

  alias Babel.Builtin

  require Builtin

  doctest Builtin

  describe "struct_module/1" do
    test "returns the module of a struct" do
      assert Builtin.struct_module(Babel.call(List, :to_string, [])) == Babel.Builtin.Call
      assert Builtin.struct_module(Babel.identity()) == Babel.Builtin.Identity
      assert Builtin.struct_module(Babel.into(%{})) == Babel.Builtin.Into
    end

    test "returns false when the it's not a struct" do
      assert Builtin.struct_module(:an_atom) == false
      assert Builtin.struct_module("a string") == false
      assert Builtin.struct_module(%{a: "map"}) == false
    end
  end

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

  describe "is_builtin_name/1" do
    test "returns true for all builtin step names" do
      builtin_step_names = [
        :call,
        :cast,
        :const,
        :fail,
        :fetch,
        :flat_map,
        :get,
        :identity,
        :into,
        :map,
        :match,
        :then,
        :try
      ]

      for name <- builtin_step_names do
        assert Builtin.is_builtin_name(name)
      end
    end

    test "returns false for anything else" do
      non_builtin_step_names = [
        :whatever,
        "whatever",
        make_ref(),
        {:tuple, "time"}
      ]

      for name <- non_builtin_step_names do
        refute Builtin.is_builtin_name(name)
      end
    end
  end

  describe "name_of_builtin!/1" do
    test "returns the expected name for each builtin step" do
      expected_name_and_step = [
        call: Babel.call(List, :to_string, []),
        cast: Babel.cast(:boolean),
        cast: Babel.cast(:float),
        cast: Babel.cast(:integer),
        const: Babel.const(:stuff),
        fail: Babel.fail(:some_reason),
        fetch: Babel.fetch("path"),
        flat_map: Babel.flat_map(fn _ -> Babel.identity() end),
        get: Babel.get("path", :default),
        identity: Babel.identity(),
        into: Babel.into(%{}),
        map: Babel.map(Babel.identity()),
        match: Babel.match(fn _ -> Babel.identity() end),
        then: Babel.then(:some_name, fn _ -> :value end),
        try: Babel.try([Babel.fail(:foobar), Babel.const(:baz)])
      ]

      for {expected_name, step} <- expected_name_and_step do
        assert Builtin.name_of_builtin!(step) == expected_name
      end
    end

    test "raises a FunctionClauseError for anything else" do
      invalid = [
        Babel.Trace,
        :whatever,
        "fooooo"
      ]

      for i <- invalid do
        assert_raise FunctionClauseError, fn -> Builtin.name_of_builtin!(i) end
      end
    end
  end

  describe "inspect/3" do
    test "includes only the given fields in the order specified" do
      call = Babel.call(Map, :fetch, [:some_key])
      # We're not using Inspect.Opts.new/1 because that's not available in Elixir versions <1.13
      opts = %Inspect.Opts{}

      assert_inspects_to(Builtin.inspect(call, [], opts), "Babel.call()")

      assert_inspects_to(
        Builtin.inspect(call, [:function, :module], opts),
        "Babel.call(:fetch, Map)"
      )
    end
  end

  defp assert_inspects_to(inspect_doc, expected) do
    inspect_string =
      inspect_doc
      |> Inspect.Algebra.format(:infinity)
      |> IO.iodata_to_binary()

    assert inspect_string == expected
  end
end
