defmodule Babel.IntoableTest do
  require Babel
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
    test "resolves an empty list" do
      assert traced_into([], nil) == {[], {:ok, []}}
    end

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

    test "collects all errors into one flat list" do
      list = [
        Babel.const(:whatever1),
        Babel.fail(:reason1),
        Babel.const(:whatever2),
        Babel.fail(:reason2),
        [Babel.fail(:reason3), [Babel.fail(:reason4)]]
      ]

      data = nil

      assert into(list, data) == {:error, [:reason1, :reason2, :reason3, :reason4]}
    end

    test "resolves an improper list to a nice proper list" do
      list =
        [
          1,
          2
          | Babel.map(Babel.then(&(&1 * 2)))
        ]

      assert into!(list, 1..5) == [1, 2, 2, 4, 6, 8, 10]
    end

    test "resolves an improper list to an improper list" do
      list =
        [
          1,
          2
          | Babel.const(:not_a_list)
        ]

      assert into!(list, nil) == [1, 2 | :not_a_list]
    end

    test "collects all errors when the improper step fails" do
      list =
        [
          1,
          2
          | Babel.fail(:reason1)
        ]

      assert into(list, nil) == {:error, [:reason1]}
    end

    test "collects all errors when it failed before and the improper step succeeds" do
      list =
        [
          1,
          2,
          Babel.fail(:reason1)
          | Babel.const([])
        ]

      assert into(list, nil) == {:error, [:reason1]}
    end

    test "collects all errors when it failed before and the improper step fails" do
      list =
        [
          1,
          2,
          Babel.fail(:reason1)
          | Babel.fail(:reason2)
        ]

      assert into(list, nil) == {:error, [:reason1, :reason2]}
    end

    test "collects all errors when it failed before and the improper step returns a nested list of failures" do
      list =
        [
          1,
          2,
          Babel.fail(:reason1)
          | Babel.try([
              Babel.fail(:reason2),
              Babel.into([Babel.const(:whatever1), Babel.fail(:reason3)])
            ])
        ]

      assert into(list, nil) == {:error, [:reason1, :reason2, :reason3]}
    end
  end

  describe "Tuple" do
    test "returns an empty tuple unchanged" do
      assert {[], {:ok, {}}} = traced_into({}, nil)
    end

    test "resolves the element of a single value tuple" do
      assert {[], {:ok, {:static}}} = traced_into({:static}, nil)

      const = Babel.const(:dynamic)
      assert {[trace], {:ok, {:dynamic}}} = traced_into({const}, nil)
      assert trace == trace(const, nil)

      fail = Babel.fail(:reason)
      assert {[trace], {:error, :reason}} = traced_into({fail}, nil)
      assert trace == trace(fail, nil)
    end

    test "resolves the elements of a two value tuple" do
      data = nil

      for value1 <- [:static1, Babel.const(:dynamic1), Babel.fail(:reason1)],
          value2 <- [:static2, Babel.const(:dynamic2), Babel.fail(:reason2)] do
        values = [value1, value2]

        {expected_traces, expected_result} = expected_traces_and_tuple_result(values, data)
        {traces, result} = traced_into({value1, value2}, data)

        assert result == expected_result
        assert traces == expected_traces
      end
    end

    test "resolves the elements of a three value tuple" do
      data = nil

      for value1 <- [:static1, Babel.const(:dynamic1), Babel.fail(:reason1)],
          value2 <- [:static2, Babel.const(:dynamic2), Babel.fail(:reason2)],
          value3 <- [:static3, Babel.const(:dynamic3), Babel.fail(:reason3)] do
        values = [value1, value2, value3]

        {expected_traces, expected_result} = expected_traces_and_tuple_result(values, data)
        {traces, result} = traced_into({value1, value2, value3}, data)

        assert result == expected_result
        assert traces == expected_traces
      end
    end

    test "resolves the elements of a four value tuple" do
      data = nil

      for value1 <- [:static1, Babel.const(:dynamic1), Babel.fail(:reason1)],
          value2 <- [:static2, Babel.const(:dynamic2), Babel.fail(:reason2)],
          value3 <- [:static3, Babel.const(:dynamic3), Babel.fail(:reason3)],
          value4 <- [:static4, Babel.const(:dynamic4), Babel.fail(:reason4)] do
        values = [value1, value2, value3, value4]

        {expected_traces, expected_result} = expected_traces_and_tuple_result(values, data)
        {traces, result} = traced_into({value1, value2, value3, value4}, data)

        assert result == expected_result
        assert traces == expected_traces
      end
    end

    test "resolves the elements of a five value tuple" do
      data = nil

      for value1 <- [:static1, Babel.const(:dynamic1), Babel.fail(:reason1)],
          value2 <- [:static2, Babel.const(:dynamic2), Babel.fail(:reason2)],
          value3 <- [:static3, Babel.const(:dynamic3), Babel.fail(:reason3)],
          value4 <- [:static4, Babel.const(:dynamic4), Babel.fail(:reason4)],
          value5 <- [:static5, Babel.const(:dynamic5), Babel.fail(:reason5)] do
        values = [value1, value2, value3, value4, value5]

        {expected_traces, expected_result} = expected_traces_and_tuple_result(values, data)
        {traces, result} = traced_into({value1, value2, value3, value4, value5}, data)

        assert result == expected_result
        assert traces == expected_traces
      end
    end

    test "resolves the elements of a six value tuple" do
      data = nil

      for value1 <- [:static1, Babel.const(:dynamic1), Babel.fail(:reason1)],
          value2 <- [:static2, Babel.const(:dynamic2), Babel.fail(:reason2)],
          value3 <- [:static3, Babel.const(:dynamic3), Babel.fail(:reason3)],
          value4 <- [:static4, Babel.const(:dynamic4), Babel.fail(:reason4)],
          value5 <- [:static5, Babel.const(:dynamic5), Babel.fail(:reason5)],
          value6 <- [:static6, Babel.const(:dynamic6), Babel.fail(:reason6)] do
        values = [value1, value2, value3, value4, value5, value6]

        {expected_traces, expected_result} = expected_traces_and_tuple_result(values, data)
        {traces, result} = traced_into({value1, value2, value3, value4, value5, value6}, data)

        assert result == expected_result
        assert traces == expected_traces
      end
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

  defp expected_traces_and_tuple_result(values, data) do
    traces_or_static =
      Enum.map(values, fn
        babel when Babel.is_babel(babel) -> trace(babel, data)
        static -> static
      end)

    results =
      Enum.map(traces_or_static, fn
        %Babel.Trace{} = trace -> Babel.Trace.result(trace)
        static -> {:ok, static}
      end)

    {
      Enum.filter(traces_or_static, &match?(%Babel.Trace{}, &1)),
      if Enum.any?(results, &match?({:error, _}, &1)) do
        {:error, for({:error, r} <- results, do: r)}
      else
        {:ok, List.to_tuple(for {:ok, r} <- results, do: r)}
      end
    }
  end

  defp sorted(enum), do: Enum.sort(enum)
end
