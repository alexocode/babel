defmodule Babel.IntoableTest do
  use ExUnit.Case, async: true

  import Babel.Test.Factory

  alias Babel.Intoable

  describe "Any" do
    test "when it's a Babel.Pipeline invokes Babel.Applicable.apply/2" do
      ref = make_ref()
      pipeline = Babel.begin() |> Babel.chain(Babel.const(ref))
      data = data()

      assert {traces, {:ok, ^ref}} = into(pipeline, data)
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
        assert {traces, result} = into(builtin, data)
        assert {builtin, data, result} == {builtin, data, expected}
        assert traces == [trace(builtin, data)]
      end
    end

    test "when it's a custom non-builtin step" do
      step = %Babel.Test.EmptyCustomStep{}

      assert {traces, result} = into(step, nil)
      assert result == {:ok, 42}
      assert traces == [trace(step, nil)]
    end

    defmodule RegularOldStruct do
      defstruct [:foo, :bar]
    end

    test "when it's a regular old struct treats it like a map" do
      step = %RegularOldStruct{foo: Babel.fetch(:foo), bar: Babel.fetch(:bar)}
      data = %{foo: make_ref(), bar: make_ref()}

      assert {traces, {:ok, result}} = into(step, data)
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
        assert into(thing, nil) == {[], {:ok, thing}}
      end
    end
  end

  describe "Map" do
    test "resolves every key and value" do
      map = %{
        %{Babel.fetch(:key1) => Babel.fetch(:key2)} =>
          Babel.begin()
          |> Babel.fetch(:range)
          |> Babel.map(Babel.then(&(&1 * 2))),
        static_key:
          Babel.begin()
          |> Babel.fetch(:value)
          |> Babel.then(&"dynamic #{&1}")
      }

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
    end
  end

  defp into(intoable, data) do
    Intoable.into(intoable, Babel.Context.new(data))
  end

  defp into!(intoable, data) do
    assert {_traces, {:ok, result}} = into(intoable, data)
    result
  end

  defp trace(babel, data), do: Babel.trace(babel, data)
end
