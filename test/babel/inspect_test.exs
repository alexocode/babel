defmodule Babel.InspectTest do
  use ExUnit.Case, async: true

  require Babel

  describe "Inspect, for: Babel.Step" do
    test "from Babel.Core" do
      step_and_inspect = %{
        Babel.id() => "Babel.id()",
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

    test "Babel.choice" do
      chooser = fn _ -> Babel.id() end
      step = Babel.choice(chooser)

      assert_inspects_as(step, "Babel.choice(#{inspect(chooser)})")
    end

    test "Babel.map" do
      step = Babel.map(Babel.id())

      assert_inspects_as(step, "Babel.map(Babel.id())")
    end

    test "Babel.flat_map" do
      mapper = fn _ -> Babel.id() end
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
      |> Babel.on_error(#{inspect(pipeline.on_error)})
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
      |> Babel.on_error(#{inspect(pipeline.on_error)})
      """)
    end
  end

  defp assert_inspects_as(thing, string) do
    assert inspect(thing) == String.trim(string)
  end
end
