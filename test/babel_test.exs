defmodule BabelTest do
  use ExUnit.Case, async: true

  alias Babel.Builtin

  require Babel

  # doctest Babel, except: [:moduledoc]
  doctest Babel

  describe "typical pipelines" do
    test "constructing a map from a nested path" do
      pipeline =
        Babel.pipeline :foobar do
          Babel.begin()
          |> Babel.fetch(["foo", 0, "bar"])
          |> Babel.into(%{
            atom_key1: Babel.fetch("key1"),
            atom_key2: Babel.fetch("key2")
          })
        end

      assert Babel.apply(pipeline, %{
               "foo" => [
                 %{"bar" => %{"key1" => "value1", "key2" => "value2"}},
                 %{"bar" => %{}},
                 %{}
               ]
             }) == {:ok, %{atom_key1: "value1", atom_key2: "value2"}}
    end

    test "with an else clause" do
      ref = make_ref()

      step =
        Babel.fetch(["does", "not", "exist"])

      pipeline =
        Babel.pipeline :foobar do
          step
        else
          error ->
            send self(), {:error, ref, error}

            {:my_return_value, ref}
        end

      data = %{"some_data" => make_ref()}

      assert Babel.apply(pipeline, data) == {:ok, {:my_return_value, ref}}
      assert_received {:error, ^ref, %Babel.Error{} = error}

      assert error.trace == %Babel.Trace{
               babel: step,
               input: data,
               output: {:error, {:not_found, "does"}}
             }
    end
  end

  describe "shortcuts" do
    test "returns the expected core steps" do
      assert Babel.noop() == Builtin.Identity.new()
      assert Babel.identity() == Builtin.Identity.new()

      assert Babel.const(:some_value) == Builtin.Const.new(:some_value)

      assert Babel.at(["some", "path"]) == Builtin.Fetch.new(["some", "path"])
      assert Babel.fetch(["some", "path"]) == Builtin.Fetch.new(["some", "path"])

      assert Babel.get(["some", "path"]) == Builtin.Get.new(["some", "path"])
      assert Babel.get(["some", "path"], :default) == Builtin.Get.new(["some", "path"], :default)

      assert Babel.cast(:boolean) == Builtin.Cast.new(:boolean)
      assert Babel.cast(:float) == Builtin.Cast.new(:float)
      assert Babel.cast(:integer) == Builtin.Cast.new(:integer)

      assert Babel.into({:some, %{value: "!"}}) == Builtin.Into.new({:some, %{value: "!"}})

      assert Babel.call(List, :to_string) == Builtin.Call.new(List, :to_string)

      assert Babel.call(Map, :put, [:key, "value"]) ==
               Builtin.Call.new(Map, :put, [:key, "value"])

      mapper = unique_step()
      assert Babel.map(mapper) == Builtin.Map.new(mapper)

      chooser = fn _ -> unique_step() end
      assert Babel.match(chooser) == Builtin.Match.new(chooser)
      assert Babel.choose(chooser) == Builtin.Match.new(chooser)

      mapper = fn _ -> unique_step() end
      assert Babel.flat_map(mapper) == Builtin.FlatMap.new(mapper)

      assert Babel.fail(:some_reason) == Builtin.Fail.new(:some_reason)

      assert Babel.root() == Builtin.Root.new()

      function = fn _ -> :do_the_thing end
      assert Babel.then(function) == Builtin.Then.new(function)
      assert Babel.then(:my_name, function) == Builtin.Then.new(:my_name, function)

      applicables = [Babel.fail(:some_reason), unique_step()]
      assert Babel.try(applicables) == Builtin.Try.new(applicables)
      assert Babel.try(applicables, :default) == Builtin.Try.new(applicables, :default)
    end
  end

  describe "composition" do
    test "most core steps have a composing version" do
      assert composes(Babel, :at, [["some", "path"]])
      assert composes(Babel, :call, [List, :to_string])
      assert composes(Babel, :call, [Map, :fetch, [:key]])
      assert composes(Babel, :cast, [:boolean])
      assert composes(Babel, :cast, [:float])
      assert composes(Babel, :cast, [:integer])
      assert composes(Babel, :choose, [fn _ -> unique_step() end])
      assert composes(Babel, :fetch, [["some", "path"]])
      assert composes(Babel, :flat_map, [fn _ -> unique_step() end])
      assert composes(Babel, :get, [["some", "path"], :default])
      assert composes(Babel, :into, [{:some, %{value: unique_step()}}])
      assert composes(Babel, :map, [unique_step()])
      assert composes(Babel, :match, [fn _ -> unique_step() end])
      assert composes(Babel, :then, [fn _ -> :do_the_thing end])
      assert composes(Babel, :then, [:my_name, fn _ -> :do_the_thing end])
      assert composes(Babel, :try, [[Babel.fail(:some_reason), unique_step()]])
      assert composes(Babel, :try, [[Babel.fail(:some_reason), unique_step()], :default])
    end

    test "chain/2 returns the right value when the left is nil" do
      right_step = unique_step()

      assert Babel.chain(nil, right_step) == right_step
    end

    test "chain/2 composes both values into a pipeline" do
      left_step = unique_step()
      right_step = unique_step()

      assert Babel.chain(left_step, right_step) == Babel.Pipeline.new([left_step, right_step])
    end
  end

  describe "on_error/2" do
    test "wraps a step in a pipeline and set it's on_error handler" do
      step = unique_step()
      on_error = fn _ -> :handle_the_error end

      assert Babel.on_error(step, on_error) == Babel.Pipeline.new(nil, on_error, step)
    end

    test "sets a pipeline's on_error handler" do
      pipeline = Babel.begin(make_ref())
      on_error = fn _ -> :handle_the_error end

      assert Babel.on_error(pipeline, on_error) == Babel.Pipeline.on_error(pipeline, on_error)
    end

    test "overrides a pipeline's existing on_error handler" do
      pipeline = Babel.Pipeline.new(make_ref(), fn _ -> :different_on_error end, [])
      on_error = fn _ -> :handle_the_error end

      assert Babel.on_error(pipeline, on_error) == Babel.Pipeline.on_error(pipeline, on_error)
    end
  end

  describe "apply/2" do
    test "returns {:ok, <result>} when everything is fine" do
      step = Babel.identity()
      data = %{value: make_ref()}

      assert Babel.apply(step, data) == {:ok, data}
    end

    test "returns {:error, Babel.Error.t} when something goes wrong" do
      step = Babel.then(fn _ -> {:error, :something_is_wrong} end)
      data = %{value: make_ref()}

      assert {:error, %Babel.Error{} = error} = Babel.apply(step, data)
      assert error.reason == :something_is_wrong
      assert error.trace == Babel.trace(step, data)
    end
  end

  describe "apply!/2" do
    test "returns <result> when everything is fine" do
      step = Babel.identity()
      data = %{value: make_ref()}

      assert Babel.apply!(step, data) == data
    end

    test "returns {:error, Babel.Error.t} when something goes wrong" do
      step = Babel.then(fn _ -> {:error, :something_is_wrong} end)
      data = %{value: make_ref()}

      error = assert_raise Babel.Error, fn -> Babel.apply!(step, data) end
      assert error.reason == :something_is_wrong
      assert error.trace == Babel.trace(step, data)
    end
  end

  describe "trace/2" do
    test "delegates to Babel.Applicable.apply/2" do
      step = Babel.identity()
      data = %{value: make_ref()}

      assert Babel.trace(step, data) == Babel.Applicable.apply(step, Babel.Context.new(data))
    end
  end

  defp composes(module, function, args) do
    pipeline = Babel.begin(make_ref())
    step = apply(module, function, args)
    composed = apply(module, function, [pipeline | args])

    assert composed == %Babel.Pipeline{pipeline | reversed_steps: [step]}
  end

  defp unique_step, do: Babel.const(make_ref())
end
