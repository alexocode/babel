defmodule Babel.Builtin.CastTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Builtin.Cast

  describe "new/1" do
    test "returns the step for :boolean | :integer | :float" do
      for type <- [:boolean, :integer, :float] do
        assert Cast.new(type) == %Cast{type: type}
      end
    end

    test "raises an ArgumentError for any other value" do
      invalid_types = [
        :list,
        :map,
        "whatever",
        fn -> ~w[the fuck] end
      ]

      for type <- invalid_types do
        assert_raise ArgumentError,
                     "invalid type #{inspect(type)}, allowed types are: :boolean | :float | :integer",
                     fn -> Cast.new(type) end
      end
    end
  end

  describe "apply/2 (:integer)" do
    test "succeeds when the value is an integer" do
      assert apply!(Cast.new(:integer), 1) == 1
      assert apply!(Cast.new(:integer), 42) == 42
      assert apply!(Cast.new(:integer), -100) == -100
    end

    test "succeeds when the value is the string representation of an integer" do
      assert apply!(Cast.new(:integer), " 1") == 1
      assert apply!(Cast.new(:integer), "42  ") == 42
      assert apply!(Cast.new(:integer), "  -100 ") == -100
    end

    test "succeeds when the value is the string representation of a float" do
      assert apply!(Cast.new(:integer), " 1.0") == 1
      assert apply!(Cast.new(:integer), "  42.2") == 42
      assert apply!(Cast.new(:integer), " -100.6 ") == -100
    end

    test "succeeds when the value is a float" do
      assert apply!(Cast.new(:integer), 1.0) == 1
      assert apply!(Cast.new(:integer), 42.2) == 42
      assert apply!(Cast.new(:integer), -100.8) == -100
    end

    test "fails when the value is a string without an integer" do
      failing = [
        "not an integer",
        "1not an integer",
        "1.0not an integer"
      ]

      for s <- failing do
        assert {:error, reason} = apply(Cast.new(:integer), s)
        assert reason == {:invalid, :integer, s}
      end
    end
  end

  describe "apply/2 (:float)" do
    test "succeeds when the value is a float" do
      assert apply!(Cast.new(:float), 1.0) == 1.0
      assert apply!(Cast.new(:float), 42.2) == 42.2
      assert apply!(Cast.new(:float), -100.8) == -100.8
    end

    test "succeeds when the value is the string representation of an float" do
      assert apply!(Cast.new(:float), " 1.0") == 1.0
      assert apply!(Cast.new(:float), "42.2 ") == 42.2
      assert apply!(Cast.new(:float), " -100.8  ") == -100.8
    end

    test "succeeds when the value is the string representation of an integer" do
      assert apply!(Cast.new(:float), "1") == 1.0
      assert apply!(Cast.new(:float), " 1.0") == 1.0
      assert apply!(Cast.new(:float), "42.2 ") == 42.2
      assert apply!(Cast.new(:float), " -100.8  ") == -100.8
    end

    test "succeeds when the value is an integer" do
      assert apply!(Cast.new(:float), 1) == 1.0
      assert apply!(Cast.new(:float), 42) == 42.0
      assert apply!(Cast.new(:float), -100) == -100.0
    end

    test "fails when the value is a string without a float" do
      failing = [
        "not a float",
        "1not a float",
        "1.0not a float"
      ]

      for s <- failing do
        assert {:error, reason} = apply(Cast.new(:float), s)
        assert reason == {:invalid, :float, s}
      end
    end
  end

  describe "apply/2 (:boolean)" do
    test "succeeds when the value is a boolean" do
      assert apply!(Cast.new(:boolean), true) == true
      assert apply!(Cast.new(:boolean), false) == false
    end

    test "succeeds when the value is the string representation of an boolean" do
      assert apply!(Cast.new(:boolean), "true") == true
      assert apply!(Cast.new(:boolean), "yES") == true
      assert apply!(Cast.new(:boolean), " yes ") == true
      assert apply!(Cast.new(:boolean), "  FALSE") == false
      assert apply!(Cast.new(:boolean), "no") == false
    end

    test "fails when the value is a string without a boolean" do
      assert {:error, reason} = apply(Cast.new(:boolean), "not a boolean")
      assert reason == {:invalid, :boolean, "not a boolean"}

      assert {:error, reason} = apply(Cast.new(:boolean), 1)
      assert reason == {:invalid, :boolean, 1}
    end
  end

  describe "inspect/2" do
    test "renders the step as expected" do
      step_and_inspect = [
        {Cast.new(:boolean), "Babel.cast(:boolean)"},
        {Cast.new(:float), "Babel.cast(:float)"},
        {Cast.new(:integer), "Babel.cast(:integer)"}
      ]

      for {step, expected} <- step_and_inspect do
        assert inspect(step) == expected
      end
    end
  end
end
