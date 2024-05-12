defmodule Babel.IntoableTest do
  use ExUnit.Case, async: true

  import Babel.Test.Factory

  describe "Any" do
    test "when it's a Babel.Pipeline invokes Babel.Applicable.apply/2" do
      ref = make_ref()
      pipeline = Babel.begin() |> Babel.chain(Babel.const(ref))
      data = data()

      assert {traces, {:ok, ^ref}} = traced_into(pipeline, data)
      assert traces == [trace(pipeline, data)]
    end

    test "when it's any of the builtin steps it invokes Babel.Applicable.apply/2" do
      ref = make_ref()

      builtin_data_result = [
        {Babel.call(Map, :put, [:ref, ref]), %{}, {:ok, %{ref: ref}}},
        {Babel.cast(:boolean), "true", {:ok, true}},
        {Babel.cast(:float), "42.0", {:ok, 42.0}},
        {Babel.cast(:integer), "42", {:ok, 42}},
        {Babel.const(ref), nil, {:ok, ref}},
        {Babel.fail(ref), nil, {:error, ref}},
        {Babel.fetch(ref), %{ref => ref}, {:ok, ref}},
        {Babel.flat_map(fn _ -> Babel.const(ref) end), 1..3, {:ok, [ref, ref, ref]}},
        {Babel.get(ref, :default), %{ref => ref}, {:ok, ref}},
        {Babel.get(:key, ref), %{}, {:ok, ref}},
        {Babel.identity(), ref, {:ok, ref}},
        {Babel.into(%{ref: ref}), nil, {:ok, %{ref: ref}}},
        {Babel.map(Babel.const(ref)), 1..3, {:ok, [ref, ref, ref]}},
        {Babel.match(fn _ -> Babel.const(ref) end), nil, {:ok, ref}},
        {Babel.then(fn _ -> ref end), nil, {:ok, ref}},
        {Babel.try([Babel.fail(ref), Babel.const(ref)]), nil, {:ok, ref}}
      ]

      for {builtin, data, expected} <- builtin_data_result do
        assert {traces, result} = traced_into(builtin, data)
        assert {builtin, data, result} == {builtin, data, expected}
        assert traces == [trace(builtin, data)]
      end
    end

    test "when it's a custom non-builtin step" do
      step = %Babel.Test.EmptyCustomStep{}

      assert {traces, result} = traced_into(step, nil)
      assert result == {:ok, 42}
      assert traces == [trace(step, nil)]
    end

    defmodule RegularOldStruct do
      defstruct [:foo, :bar]
    end

    test "when it's a regular old struct treats it like a map" do
      step = %RegularOldStruct{foo: Babel.fetch(:foo), bar: Babel.fetch(:bar)}
      data = %{foo: make_ref(), bar: make_ref()}

      assert {traces, {:ok, result}} = traced_into(step, data)
      assert result == %RegularOldStruct{foo: data.foo, bar: data.bar}
      assert traces == [trace(step.foo, data), trace(step.bar, data)]
    end

    test "when it's anything else it just leaves it as it is" do
      anything_else = [
        :foo,
        "bar",
        42,
        42.0,
        make_ref(),
        self()
      ]

      for thing <- anything_else do
        assert traced_into(thing, nil) == {[], {:ok, thing}}
      end
    end
  end

  describe "Map" do
    test "resolves every key and value" do
      step1 = Babel.fetch(:key1)
      step2 = Babel.fetch(:key2)

      pipeline1 =
        Babel.begin()
        |> Babel.fetch(:range)
        |> Babel.map(Babel.then(&(&1 * 2)))

      pipeline2 =
        Babel.begin()
        |> Babel.fetch(:value)
        |> Babel.then(&"dynamic #{&1}")

      map = %{%{step1 => step2} => pipeline1, static_key: pipeline2}

      data = %{
        key1: "value1",
        key2: "value2",
        range: 1..3,
        value: "value!"
      }

      assert into!(map, data) == %{
               %{"value1" => "value2"} => [2, 4, 6],
               static_key: "dynamic value!"
             }

      assert {traces, _} = traced_into(map, data)
      assert length(traces) == 4
      assert trace(step1, data) in traces
      assert trace(step2, data) in traces
      assert trace(pipeline1, data) in traces
      assert trace(pipeline2, data) in traces
    end

    test "collects all errors into one flat list" do
      map = %{
        Babel.fail(:reason1) => Babel.fail(:reason2),
        static_key: Babel.fetch(:range) |> Babel.map(Babel.then(&{:error, {&1, :reason3}}))
      }

      data = %{range: 1..3}

      assert {:error, reasons} = into(map, data)

      assert sorted(reasons) ==
               sorted([:reason1, :reason2, {1, :reason3}, {2, :reason3}, {3, :reason3}])
    end
  end

  describe "List" do
    test "resolves every value and also nested lists" do
      list = [
        :foo,
        Babel.fetch(:bar),
        [
          Babel.fetch(:boing)
        ]
      ]

      data = %{bar: "baz", boing: "whatever"}

      assert into!(list, data) == [:foo, "baz", ["whatever"]]
      assert {traces, _} = traced_into(list, data)

      assert traces == [
               trace(Babel.fetch(:bar), data),
               trace(Babel.fetch(:boing), data)
             ]
    end

    test "resolves an improper list" do
      list =
        [
          1,
          2
          | Babel.map(Babel.then(&(&1 * 2)))
        ]

      data = 1..5

      assert into!(list, data) == [1, 2, 2, 4, 6, 8, 10]

      list =
        [
          1,
          2
          | Babel.const(:not_a_list)
        ]

      data = nil

      assert into!(list, data) == [1, 2 | :not_a_list]
    end

    test "collects all errors into one flat list" do
      list = [Babel.fail(:reason1), [Babel.fail(:reason2), [Babel.fail(:reason3)]]]
      data = nil

      assert into(list, data) == {:error, [:reason1, :reason2, :reason3]}
    end
  end

  defp traced_into(intoable, data) do
    Babel.Intoable.into(intoable, Babel.Context.new(data))
  end

  defp into(intoable, data) do
    assert {_traces, result} = traced_into(intoable, data)
    result
  end

  defp into!(intoable, data) do
    assert {:ok, result} = into(intoable, data)
    result
  end

  defp trace(babel, data), do: Babel.trace(babel, data)

  defp sorted(enum), do: Enum.sort(enum)
end
