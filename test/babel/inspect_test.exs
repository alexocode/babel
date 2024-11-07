defmodule Babel.InspectTest do
  use ExUnit.Case, async: true

  require Babel

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

    test "with a nested pipeline" do
      pipeline =
        :pipeline1
        |> Babel.begin()
        |> Babel.fetch(["foo", "bar"])
        |> Babel.chain(
          :pipeline2
          |> Babel.begin()
          |> Babel.map(Babel.into(%{}))
        )

      assert_inspects_as(pipeline, """
      :pipeline1
      |> Babel.begin()
      |> Babel.fetch(["foo", "bar"])
      |> Babel.chain(
        :pipeline2
        |> Babel.begin()
        |> Babel.map(Babel.into(%{}))
      )
      """)
    end

    test "with a step that doesn't have a chaining shortcut" do
      pipeline = Babel.begin() |> Babel.chain(Babel.identity())

      assert_inspects_as(pipeline, """
      Babel.begin() |> Babel.chain(Babel.identity())
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
      trace = Babel.trace(step, data)

      assert_inspects_as(trace, [custom_options: [depth: :infinity]], [
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

    test "allows to indent the rendered trace" do
      step = Babel.identity()
      data = %{"value1" => :super_cool}
      trace = Babel.trace(step, data)

      assert_inspects_as(trace, [custom_options: [indent: 2]], [
        ~s'  Babel.Trace<OK>{',
        ~s'    data = #{i(data)}',
        ~s'    ',
        ~s'    Babel.identity()',
        ~s'    |=> %{"value1" => :super_cool}',
        ~s'  }'
      ])
    end

    test "renders an ERROR state when the result is an error" do
      step = Babel.fail(:some_reason)
      data = %{}
      trace = Babel.trace(step, data)

      assert_inspects_as(trace, [
        "Babel.Trace<ERROR>{",
        "  data = #{i(data)}",
        "  ",
        "  Babel.fail(:some_reason)",
        "  |=> {:error, :some_reason}",
        "}"
      ])
    end

    test "by default renders a pipeline by only rendering the result" do
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

      trace = Babel.trace(pipeline, data)

      assert_inspects_as(
        trace,
        [
          ~s'Babel.Trace<OK>{',
          ~s'  data =',
          ~s'    #{i(data, indent: 4)}',
          ~s'  ',
          ~s'  Babel.Pipeline<>',
          ~s'  | ',
          ~s'  | ... traces omitted (4) ...',
          ~s'  | ',
          ~s'  |=> %{atom_key1: :value1, atom_key2: :value2}',
          ~s'}'
        ]
      )
    end

    test "renders a pipeline in more depth when passing the custom option `depth`" do
      pipeline =
        Babel.begin()
        |> Babel.fetch(["foo", 0, "bar"])
        |> Babel.into(%{
          atom_key1:
            :cool_transform
            |> Babel.begin()
            |> Babel.fetch("key1")
            |> Babel.call(Atom, :to_string)
            |> Babel.chain(
              :nested_pipeline
              |> Babel.begin()
              |> Babel.call(Function, :identity)
            ),
          atom_key2: Babel.fetch("key2")
        })
        |> Babel.on_error(fn _error -> :do_the_thing end)

      data = %{
        "foo" => [
          %{"bar" => %{"key1" => :value1, "key2" => :value2}},
          %{"something" => :else}
        ]
      }

      trace = Babel.trace(pipeline, data)

      assert_inspects_as(
        trace,
        [custom_options: [depth: 1]],
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
          ~s'  | Babel.into(%{atom_key1: :cool_transform |> Babel.begin() |> Babel.fetch("key1") |> Babel.call(Atom, :to_string) |> Babel.chain(:nested_pipeline |> Babel.begin() |> Babel.call(Function, :identity)), atom_key2: Babel.fetch("key2")})',
          ~s'  | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | ',
          ~s'  | | ... traces omitted (6) ...',
          ~s'  | | ',
          ~s'  | |=> %{atom_key1: "value1", atom_key2: :value2}',
          ~s'  | ',
          ~s'  |=> %{atom_key1: "value1", atom_key2: :value2}',
          ~s'}'
        ]
      )

      assert_inspects_as(
        trace,
        [custom_options: [depth: 2]],
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
          ~s'  | Babel.into(%{atom_key1: :cool_transform |> Babel.begin() |> Babel.fetch("key1") |> Babel.call(Atom, :to_string) |> Babel.chain(:nested_pipeline |> Babel.begin() |> Babel.call(Function, :identity)), atom_key2: Babel.fetch("key2")})',
          ~s'  | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | ',
          ~s'  | | Babel.Pipeline<:cool_transform>',
          ~s'  | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | | ',
          ~s'  | | | ... traces omitted (4) ...',
          ~s'  | | | ',
          ~s'  | | |=> "value1"',
          ~s'  | | ',
          ~s'  | | Babel.fetch("key2")',
          ~s'  | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | |=> :value2',
          ~s'  | | ',
          ~s'  | |=> %{atom_key1: "value1", atom_key2: :value2}',
          ~s'  | ',
          ~s'  |=> %{atom_key1: "value1", atom_key2: :value2}',
          ~s'}'
        ]
      )

      assert_inspects_as(
        trace,
        [custom_options: [depth: :infinity]],
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
          ~s'  | Babel.into(%{atom_key1: :cool_transform |> Babel.begin() |> Babel.fetch("key1") |> Babel.call(Atom, :to_string) |> Babel.chain(:nested_pipeline |> Babel.begin() |> Babel.call(Function, :identity)), atom_key2: Babel.fetch("key2")})',
          ~s'  | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | ',
          ~s'  | | Babel.Pipeline<:cool_transform>',
          ~s'  | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | | ',
          ~s'  | | | Babel.fetch("key1")',
          ~s'  | | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | | |=> :value1',
          ~s'  | | | ',
          ~s'  | | | Babel.call(Atom, :to_string)',
          ~s'  | | | |=< :value1',
          ~s'  | | | |=> "value1"',
          ~s'  | | | ',
          ~s'  | | | Babel.Pipeline<:nested_pipeline>',
          ~s'  | | | |=< "value1"',
          ~s'  | | | | ',
          ~s'  | | | | Babel.call(Function, :identity)',
          ~s'  | | | | |=< "value1"',
          ~s'  | | | | |=> "value1"',
          ~s'  | | | | ',
          ~s'  | | | |=> "value1"',
          ~s'  | | | ',
          ~s'  | | |=> "value1"',
          ~s'  | | ',
          ~s'  | | Babel.fetch("key2")',
          ~s'  | | |=< %{"key1" => :value1, "key2" => :value2}',
          ~s'  | | |=> :value2',
          ~s'  | | ',
          ~s'  | |=> %{atom_key1: "value1", atom_key2: :value2}',
          ~s'  | ',
          ~s'  |=> %{atom_key1: "value1", atom_key2: :value2}',
          ~s'}'
        ]
      )
    end

    test "renders nested error traces if the root trace is an error" do
      pipeline =
        Babel.begin()
        |> Babel.fetch(["foo", 0, "bar"])
        |> Babel.into(%{
          atom_key1: Babel.fetch("key1"),
          atom_key2: Babel.fetch("key2")
        })

      data = %{
        "foo" => [
          %{"bar" => %{"key1" => :value1, "key3" => :value3}},
          %{"something" => :else}
        ]
      }

      trace = Babel.trace(pipeline, data)

      assert_inspects_as(
        trace,
        [
          ~s'Babel.Trace<ERROR>{',
          ~s'  data =',
          ~s'    #{i(data, indent: 4)}',
          ~s'  ',
          ~s'  Babel.Pipeline<>',
          ~s'  | ',
          ~s'  | ... traces omitted (4) ...',
          ~s'  | ',
          ~s'  | Babel.into(%{atom_key1: Babel.fetch("key1"), atom_key2: Babel.fetch("key2")})',
          ~s'  | |=< %{"key1" => :value1, "key3" => :value3}',
          ~s'  | | ',
          ~s'  | | ... traces omitted (1) ...',
          ~s'  | | ',
          ~s'  | | Babel.fetch("key2")',
          ~s'  | | |=< %{"key1" => :value1, "key3" => :value3}',
          ~s'  | | |=> {:error, {:not_found, "key2"}}',
          ~s'  | | ',
          ~s'  | |=> {:error, [not_found: "key2"]}',
          ~s'  | ',
          ~s'  |=> {:error, [not_found: "key2"]}',
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

      data = [:invalid, "data"]

      trace = Babel.trace(pipeline, data)

      assert_inspects_as(trace, [custom_options: [depth: :infinity]], [
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

  defp assert_inspects_as(thing, opts \\ [], expected)

  defp assert_inspects_as(thing, opts, expected_lines) when is_list(expected_lines) do
    inspect_thing_lines =
      thing
      |> inspect(Keyword.put_new(opts, :pretty, true))
      |> String.split("\n")

    expected_lines = Enum.flat_map(expected_lines, &String.split(&1, "\n"))

    assert inspect_thing_lines == expected_lines
  end

  defp assert_inspects_as(thing, opts, string) when is_binary(string) do
    lines = String.split(string, "\n", trim: true)

    if length(lines) > 1 do
      assert_inspects_as(thing, lines)
    else
      assert inspect(thing, opts) == String.trim(string)
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
