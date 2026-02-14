defmodule Babel.ContextTest do
  use Babel.Test.StepCase, async: true

  alias Babel.Context

  describe "new/3" do
    test "creates a context with data, history, and private" do
      data = %{key: :value}
      history = [make_ref()]
      private = %{session_id: "abc123"}

      context = Context.new(data, history, private)

      assert context.data == data
      assert context.history == history
      assert context.private == private
    end

    test "defaults private to empty map when not provided" do
      data = %{key: :value}

      context = Context.new(data)

      assert context.data == data
      assert context.history == []
      assert context.private == %{}
    end

    test "defaults private to empty map when only history provided" do
      data = %{key: :value}
      history = [make_ref()]

      context = Context.new(data, history)

      assert context.data == data
      assert context.history == history
      assert context.private == %{}
    end
  end

  describe "private context in steps" do
    test "step can return {:ok, data, private} to update private" do
      step = Babel.then(fn data ->
        {:ok, Map.put(data, :processed, true), %{step_ran: :first}}
      end)

      result = Babel.apply(step, %{input: :data})

      assert {:ok, output} = result
      assert output == %{input: :data, processed: true}
    end

    test "private flows through pipeline" do
      pipeline =
        Babel.then(fn data ->
          {:ok, Map.put(data, :step1, true), %{ran_step: 1}}
        end)
        |> Babel.chain(Babel.then(fn data ->
          {:ok, Map.put(data, :step2, true), %{ran_step: 2}}
        end))

      result = Babel.apply(pipeline, %{start: true})

      assert {:ok, output} = result
      assert output == %{start: true, step1: true, step2: true}
    end

    test "private is accessible from subsequent steps using ContextStep" do
      step1 = Babel.then(fn data ->
        {:ok, data, %{session_id: "xyz789"}}
      end)

      step2 = Babel.Test.ContextStep.new(fn %Context{data: data, private: private} ->
        {:ok, Map.put(data, :session_from_private, private[:session_id])}
      end)

      pipeline = Babel.chain(step1, step2)
      result = Babel.apply(pipeline, %{value: 42})

      assert {:ok, output} = result
      assert output.value == 42
      assert output.session_from_private == "xyz789"
    end

    test "private is merged when multiple steps return private" do
      pipeline =
        Babel.then(fn data -> {:ok, data, %{key1: :value1}} end)
        |> Babel.chain(Babel.then(fn data -> {:ok, data, %{key2: :value2}} end))
        |> Babel.chain(Babel.then(fn data -> {:ok, data, %{key3: :value3}} end))

      step_to_check_private = Babel.Test.ContextStep.new(fn %Context{private: private} = ctx ->
        # Verify all keys accumulated
        assert private.key1 == :value1
        assert private.key2 == :value2
        assert private.key3 == :value3
        {:ok, ctx.data}
      end)

      final_pipeline = Babel.chain(pipeline, step_to_check_private)

      assert {:ok, _} = Babel.apply(final_pipeline, %{})
    end

    test "later private values overwrite earlier ones for same keys" do
      pipeline =
        Babel.then(fn data -> {:ok, data, %{counter: 1}} end)
        |> Babel.chain(Babel.then(fn data -> {:ok, data, %{counter: 2}} end))
        |> Babel.chain(Babel.then(fn data -> {:ok, data, %{counter: 3}} end))

      step_to_check_private = Babel.Test.ContextStep.new(fn %Context{private: private} = ctx ->
        assert private.counter == 3
        {:ok, ctx.data}
      end)

      final_pipeline = Babel.chain(pipeline, step_to_check_private)

      assert {:ok, _} = Babel.apply(final_pipeline, %{})
    end

    test "backward compatibility: {:ok, data} still works" do
      step = Babel.then(fn data ->
        {:ok, Map.put(data, :processed, true)}
      end)

      result = Babel.apply(step, %{input: :data})

      assert {:ok, output} = result
      assert output == %{input: :data, processed: true}
    end

    test "step can return {:ok, data, private} with keyword list" do
      step = Babel.then(fn data ->
        {:ok, Map.put(data, :processed, true), session_id: "abc", user_id: 123}
      end)

      result = Babel.apply(step, %{input: :data})

      assert {:ok, output} = result
      assert output == %{input: :data, processed: true}
    end

    test "keyword list private is accessible from subsequent steps" do
      step1 = Babel.then(fn data ->
        {:ok, data, session_id: "xyz789", authenticated: true}
      end)

      step2 = Babel.Test.ContextStep.new(fn %Context{data: data, private: private} ->
        assert private.session_id == "xyz789"
        assert private.authenticated == true
        {:ok, Map.put(data, :verified, true)}
      end)

      pipeline = Babel.chain(step1, step2)
      result = Babel.apply(pipeline, %{value: 42})

      assert {:ok, output} = result
      assert output.value == 42
      assert output.verified == true
    end
  end
end
