defmodule Babel.InspectTest do
  use ExUnit.Case, async: true

  require Babel

  describe "Inspect, for: Babel.Step" do
    test "from Babel.Builtin" do
      step_and_inspect = %{
        Babel.identity() => "Babel.identity()",
        Babel.const(:value) => "Babel.const(:value)",
        Babel.fetch("foo") => "Babel.fetch(\"foo\")",
        Babel.fetch(["foo", :bar]) => "Babel.fetch([\"foo\", :bar])",
        Babel.get("foo", :default) => "Babel.get(\"foo\", :default)",
        Babel.cast(:boolean) => "Babel.cast(:boolean)",
        Babel.into([Babel.const(0)]) => "Babel.into([Babel.const(0)])",
        Babel.call(List, :to_string) => "Babel.call(List, :to_string, [])"
      }

      for {step, inspect} <- step_and_inspect do
        assert_inspects_as(step, inspect)
      end
    end

    test "Babel.then" do
      function = fn _ -> :stuff end
      step = Babel.then(function)

      assert_inspects_as(step, "Babel.then(#{inspect(function)})")

      step = Babel.then(:my_name, function)

      assert_inspects_as(step, "Babel.then(:my_name, #{inspect(function)})")
    end

    test "Babel.match" do
      chooser = fn _ -> Babel.identity() end
      step = Babel.match(chooser)

      assert_inspects_as(step, "Babel.match(#{inspect(chooser)})")
    end

    test "Babel.map" do
      step = Babel.map(Babel.identity())

      assert_inspects_as(step, "Babel.map(Babel.identity())")
    end

    test "Babel.flat_map" do
      mapper = fn _ -> Babel.identity() end
      step = Babel.flat_map(mapper)

      assert_inspects_as(step, "Babel.flat_map(#{inspect(mapper)})")
    end

    test "Babel.Step.new" do
      name = :my_cool_step
      function = fn _ -> :my_cool_function end
      step = Babel.Step.new(name, function)

      assert_inspects_as(step, "Babel.Step.new(:my_cool_step, #{inspect(function)})")
    end
  end

  describe "Inspect, for: Babel.Pipeline" do
    test "without name" do
      pipeline =
        Babel.begin()
        |> Babel.fetch(["foo", 0, "bar"])
        |> Babel.into(%{
          atom_key1: Babel.fetch("key1"),
          atom_key2: Babel.fetch("key2")
        })

      assert_inspects_as(pipeline, """
      Babel.begin()
      |> Babel.fetch(["foo", 0, "bar"])
      |> Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})
      """)
    end

    test "with a name" do
      pipeline =
        {:my_cool, "NAME!"}
        |> Babel.begin()
        |> Babel.fetch(["foo", 0, "bar"])
        |> Babel.into(%{
          atom_key1: Babel.fetch("key1"),
          atom_key2: Babel.fetch("key2")
        })

      assert_inspects_as(pipeline, """
      {:my_cool, "NAME!"}
      |> Babel.begin()
      |> Babel.fetch(["foo", 0, "bar"])
      |> Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})
      """)
    end

    test "with on_error" do
      pipeline =
        Babel.begin()
        |> Babel.fetch(["foo", 0, "bar"])
        |> Babel.on_error(fn _error -> :do_the_thing end)
        |> Babel.into(%{
          atom_key1: Babel.fetch("key1"),
          atom_key2: Babel.fetch("key2")
        })

      assert_inspects_as(pipeline, """
      Babel.begin()
      |> Babel.fetch(["foo", 0, "bar"])
      |> Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})
      |> Babel.on_error(#{inspect(pipeline.on_error.handler)})
      """)
    end

    test "when using Babel.pipeline/2" do
      pipeline =
        Babel.pipeline :foobar do
          Babel.begin()
          |> Babel.fetch(["foo", 0, "bar"])
          |> Babel.into(%{
            atom_key1: Babel.fetch("key1"),
            atom_key2: Babel.fetch("key2")
          })
        end

      assert_inspects_as(pipeline, """
      :foobar
      |> Babel.begin()
      |> Babel.fetch(["foo", 0, "bar"])
      |> Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})
      """)

      pipeline =
        Babel.pipeline :foobar do
          Babel.begin()
          |> Babel.fetch(["foo", 0, "bar"])
          |> Babel.into(%{
            atom_key1: Babel.fetch("key1"),
            atom_key2: Babel.fetch("key2")
          })
        else
          _error -> :recover_stuff
        end

      assert_inspects_as(pipeline, """
      :foobar
      |> Babel.begin()
      |> Babel.fetch(["foo", 0, "bar"])
      |> Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})
      |> Babel.on_error(#{inspect(pipeline.on_error.handler)})
      """)
    end
  end

  describe "Inspect, for: Babel.Trace" do
    test "renders the step and the result for the given data" do
      step = Babel.into(%{nested: %{map: Babel.fetch("value1")}})
      data = %{"value1" => :super_cool}
      trace = Babel.Trace.apply(step, data)

      assert_inspects_as(trace, [
        ~s'Babel.Trace<OK>{',
        ~s'  data = #{i(data)}',
        ~s'  ',
        ~s'  Babel.into(%{nested: %{map: Babel.fetch("value1")}})',
        ~s'  | ',
        ~s'  | Babel.fetch("value1")',
        ~s'  | |=< #{inspect(data)}',
        ~s'  | |=> :super_cool',
        ~s'  | ',
        ~s'  |=> %{nested: %{map: :super_cool}}',
        ~s'}'
      ])
    end

    test "renders an ERROR state when the result is an error" do
      step = Babel.fail(:some_reason)
      data = %{}
      trace = Babel.Trace.apply(step, data)

      assert_inspects_as(trace, [
        "Babel.Trace<ERROR>{",
        "  data = #{i(data)}",
        "  ",
        "  Babel.fail(:some_reason)",
        "  |=> {:error, :some_reason}",
        "}"
      ])
    end

    test "renders a pipeline by rendering all nested steps and their results" do
      pipeline =
        Babel.begin()
        |> Babel.fetch(["foo", 0, "bar"])
        |> Babel.into(%{
          atom_key1: Babel.fetch("key1"),
          atom_key2: Babel.fetch("key2")
        })
        |> Babel.on_error(fn _error -> :do_the_thing end)

      data = %{
        "foo" => [
          %{"bar" => %{"key1" => :value1, "key2" => :value2}},
          %{"something" => :else}
        ]
      }

      trace = Babel.Trace.apply(pipeline, data)

      assert_inspects_as(
        trace,
        [
          ~s'Babel.Trace<OK>{',
          ~s'  data =',
          ~s'    #{i(data, indent: 4)}',
          ~s'  ',
          ~s'  Babel.Pipeline<>',
          ~s'  | ',
          ~s'  | Babel.fetch(["foo", 0, "bar"])',
          ~s'  | |=< #{inspect(data)}',
          ~s'  | |=> %{"key1" => :value1, "key2" => :value2}',
          ~s'  | ',
          ~s'  | Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})',
          ~s'  | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | ',
          ~s'  | | Babel.fetch("key1")',
          ~s'  | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | |=> :value1',
          ~s'  | | ',
          ~s'  | | Babel.fetch("key2")',
          ~s'  | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | |=> :value2',
          ~s'  | | ',
          ~s'  | |=> %{atom_key1: :value1, atom_key2: :value2}',
          ~s'  | ',
          ~s'  |=> %{atom_key1: :value1, atom_key2: :value2}',
          ~s'}'
        ]
      )
    end

    test "includes a pipelines on_error handling when relevant" do
      on_error = fn _error -> :recovered_value end

      pipeline =
        :my_error_handling_pipeline
        |> Babel.begin()
        |> Babel.fetch("key1")
        |> Babel.on_error(on_error)

      data = {:invalid, "data"}

      trace = Babel.Trace.apply(pipeline, data)

      assert_inspects_as(trace, [
        ~s'Babel.Trace<OK>{',
        ~s'  data = #{i(data)}',
        ~s'  ',
        ~s'  Babel.Pipeline<:my_error_handling_pipeline>',
        ~s'  | ',
        ~s'  | Babel.fetch("key1")',
        ~s'  | |=< #{inspect(data)}',
        ~s'  | |=> {:error, {:not_found, "key1"}}',
        ~s'  | ',
        ~s'  | Babel.on_error(#{inspect(on_error)})',
        ~s'  | |=< {:error, {:not_found, "key1"}}',
        ~s'  | |=> :recovered_value',
        ~s'  | ',
        ~s'  |=> :recovered_value',
        ~s'}'
      ])
    end
  end

  defp assert_inspects_as(thing, expected_lines) when is_list(expected_lines) do
    inspect_thing_lines = String.split(inspect(thing, pretty: true), "\n")
    expected_lines = Enum.flat_map(expected_lines, &String.split(&1, "\n"))

    assert inspect_thing_lines == expected_lines
  end

  defp assert_inspects_as(thing, string) when is_binary(string) do
    lines = String.split(string, "\n", trim: true)

    if length(lines) > 1 do
      assert_inspects_as(thing, lines)
    else
      assert inspect(thing) == String.trim(string)
    end
  end

  defp i(thing, opts \\ []) do
    {level, opts} = Keyword.pop(opts, :indent, 2)
    indent = indent(level)

    thing
    |> inspect(Keyword.merge([pretty: true], opts))
    |> String.split("\n")
    |> case do
      [line] -> [line]
      [line | split] -> [line | Enum.map(split, &(indent <> &1))]
    end
    |> Enum.join("\n")
  end

  defp indent(level, indent \\ "")
  defp indent(0, indent), do: indent
  defp indent(level, indent) when level > 0, do: indent(level - 1, " " <> indent)
end
