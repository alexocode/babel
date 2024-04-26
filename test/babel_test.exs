defmodule BabelTest do
  use ExUnit.Case, async: true

  import Babel.Sigils

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

    test "using the ~B sigil" do
      pipeline =
        Babel.pipeline :foobar do
          Babel.begin()
          |> Babel.fetch(["foo", 0, "bar"])
          |> Babel.into(%{
            atom_key1_0: ~B"key1[0]",
            atom_key1_2: ~B"key1.1",
            atom_key2: ~B'key2["nested1"].nested1\.1'
          })
        end

      assert Babel.apply(pipeline, %{
               "foo" => [
                 %{
                   "bar" => %{
                     "key1" => ["value1.0", "value1.1", "value1.2"],
                     "key2" => %{"nested1" => %{"nested1.1" => "value2"}}
                   }
                 },
                 %{"bar" => %{}},
                 %{}
               ]
             }) == {:ok, %{atom_key1_0: "value1.0", atom_key1_2: "value1.2", atom_key2: "value2"}}
    end

    test "with an else clause" do
      ref = make_ref()

      pipeline =
        Babel.pipeline :foobar do
          Babel.fetch(["does", "not", "exist"])
        else
          error ->
            send self(), {:error, ref, error}

            {:my_return_value, ref}
        end

      data = %{"some_data" => make_ref()}

      assert Babel.apply(pipeline, data) == {:my_return_value, ref}
      assert_received {:error, ^ref, %Babel.Error{} = error}
      assert error.data == data
    end
  end
end
