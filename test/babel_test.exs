defmodule BabelTest do
  use ExUnit.Case, async: true

  require Babel

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
               data: data,
               result: {:error, {:not_found, "does"}}
             }
    end
  end
end
