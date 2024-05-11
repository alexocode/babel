defmodule Babel.FetchableTest do
  use ExUnit.Case, async: true

  # import Babel.Test.Factory

  alias Babel.Fetchable

  describe "Structs" do
    defmodule MyStruct do
      defstruct [:foo, :bar]
    end

    defmodule MyStructWithAccess do
      @behaviour Access
      defstruct [:annotate]

      def fetch(%__MODULE__{annotate: a}, key), do: {:ok, {key, a}}
      def get_and_update(_t, _key, _function), do: :error
      def pop(_t, _key), do: :error
    end

    test "treats it like a map" do
      struct = %MyStruct{foo: make_ref(), bar: make_ref()}

      assert Fetchable.fetch(struct, :foo) == {:ok, struct.foo}
      assert Fetchable.fetch(struct, :bar) == {:ok, struct.bar}
      assert Fetchable.fetch(struct, :blubb) == :error
    end

    test "respects an implementation of the Access behaviour" do
      ref = make_ref()
      struct = %MyStructWithAccess{annotate: ref}

      assert Fetchable.fetch(struct, :foo) == {:ok, {:foo, ref}}
      assert Fetchable.fetch(struct, :bar) == {:ok, {:bar, ref}}
    end
  end

  describe "Map" do
    test "delegates to Map.fetch/2" do
      maps_keys = [
        {%{}, :key},
        {%{}, "another_key"},
        {%{foo: "bar"}, :foo}
      ]

      for {map, key} <- maps_keys do
        assert Fetchable.fetch(map, key) == Map.fetch(map, key)
      end
    end
  end

  describe "List" do
    test "fetches the element at the given index when the path segment is an integer" do
      list = [:first, :second, :third]

      lists_indizes_results = [
        {list, 0, {:ok, :first}},
        {list, 1, {:ok, :second}},
        {list, 2, {:ok, :third}},
        {list, 3, :error}
      ]

      for {list, index, result} <- lists_indizes_results do
        assert Fetchable.fetch(list, index) == result
      end
    end

    test "fetches the element counting from the end, when the path segment is a negative integer" do
      list = [:first, :second, :third]

      lists_indizes_results = [
        {list, -1, {:ok, :third}},
        {list, -2, {:ok, :second}},
        {list, -3, {:ok, :first}},
        {list, -4, :error}
      ]

      for {list, index, result} <- lists_indizes_results do
        assert Fetchable.fetch(list, index) == result
      end
    end

    test "when it's a two-value tuple list, finds the value whose first tuple value matches the given path segment" do
      ref = make_ref()

      list = [
        {:foo, :first},
        {"bar", :second},
        {ref, :third}
      ]

      lists_indizes_results = [
        {list, :foo, {:ok, :first}},
        {list, "bar", {:ok, :second}},
        {list, ref, {:ok, :third}},
        {list, "nope", :error}
      ]

      for {list, index, result} <- lists_indizes_results do
        assert Fetchable.fetch(list, index) == result
      end
    end
  end

  describe "Tuple" do
    test "fetches the element at the given index when the path segment is an integer" do
      tuple = {:first, :second, :third}

      tuples_indizes_results = [
        {tuple, 0, {:ok, :first}},
        {tuple, 1, {:ok, :second}},
        {tuple, 2, {:ok, :third}},
        {tuple, 3, :error}
      ]

      for {tuple, index, result} <- tuples_indizes_results do
        assert Fetchable.fetch(tuple, index) == result
      end
    end

    test "fetches the element counting from the end, when the path segment is a negative integer" do
      tuple = {:first, :second, :third}

      tuples_indizes_results = [
        {tuple, -1, {:ok, :third}},
        {tuple, -2, {:ok, :second}},
        {tuple, -3, {:ok, :first}},
        {tuple, -4, :error}
      ]

      for {tuple, index, result} <- tuples_indizes_results do
        assert Fetchable.fetch(tuple, index) == result
      end
    end

    test "always returns an error when the path segment is anything but an integer" do
      non_integers = [
        :foo,
        "bar",
        make_ref(),
        42.0,
        [],
        %{}
      ]

      tuple = List.to_tuple(non_integers)

      for path_segment <- non_integers do
        assert Fetchable.fetch(tuple, path_segment) ==
                 {:error, {:not_supported, Babel.Fetchable.Tuple, path_segment}}
      end
    end
  end

  describe "Any" do
    test "returns {:error, {:not_implemented, Babel.Fetchable, <data>}}" do
      everything_else = [
        :atom,
        "string",
        make_ref(),
        self()
      ]

      for thing <- everything_else do
        expected_error = {:error, {:not_implemented, Babel.Fetchable, thing}}

        assert Fetchable.fetch(thing, 0) == expected_error
        assert Fetchable.fetch(thing, :foo) == expected_error
        assert Fetchable.fetch(thing, "bar") == expected_error
      end
    end
  end
end
