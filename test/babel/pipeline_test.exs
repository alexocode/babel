defmodule Babel.PipelineTest do
  use ExUnit.Case, async: true

  import Babel.Test.StepFactory

  alias Babel.Pipeline

  describe "new/1" do
    test "returns a pipeline with the given single step" do
      step = step()

      assert Pipeline.new(step) == %Pipeline{reversed_steps: [step]}
    end

    test "returns a pipeline with the given list of steps" do
      step1 = step()
      step2 = step()

      assert Pipeline.new([step1, step2]) == %Pipeline{reversed_steps: [step2, step1]}
    end

    test "returns the pipeline that was given as step" do
      pipeline = pipeline()

      assert Pipeline.new(pipeline) == pipeline
    end
  end

  describe "new/2" do
    test "returns a pipeline with the given name" do
      name = {:my_pipeline, make_ref()}
      step1 = step()
      step2 = step()

      assert Pipeline.new(name, [step1, step2]) == %Pipeline{
               name: name,
               reversed_steps: [step2, step1]
             }
    end

    test "returns the pipeline that was given with the name set (when the name was nil)" do
      name = {:my_pipeline, make_ref()}
      pipeline = pipeline(name: nil)

      assert Pipeline.new(name, pipeline) == %Pipeline{pipeline | name: name}
    end

    test "returns the pipeline that was given (when the name was identical)" do
      name = {:my_pipeline, make_ref()}
      pipeline = pipeline(name: name)

      assert Pipeline.new(name, pipeline) == pipeline
    end
  end

  describe "new/3" do
    test "returns a pipeline with the given name and on_error handler" do
      name = {:my_pipeline, make_ref()}
      on_error = fn _ -> {:recovered, name} end
      step1 = step()
      step2 = step()

      assert Pipeline.new(name, on_error, [step1, step2]) == %Pipeline{
               name: name,
               on_error: Pipeline.OnError.new(on_error),
               reversed_steps: [step2, step1]
             }
    end

    test "returns the pipeline that was given with on_error set (when on_error was nil)" do
      name = {:my_pipeline, make_ref()}
      on_error = fn _ -> {:recovered, name} end
      pipeline = pipeline(name: name, on_error: nil)

      assert Pipeline.new(name, on_error, pipeline) == %Pipeline{
               pipeline
               | on_error: Pipeline.OnError.new(on_error)
             }
    end

    test "returns the pipeline that was given (when on_error was identical)" do
      name = {:my_pipeline, make_ref()}
      on_error = fn _ -> {:recovered, name} end
      pipeline = pipeline(name: name, on_error: on_error)

      assert Pipeline.new(name, on_error, pipeline) == pipeline
    end
  end

  defp pipeline(attrs \\ []) do
    Pipeline.new(
      Keyword.get_lazy(attrs, :name, fn -> {:test, make_ref()} end),
      Keyword.get_lazy(attrs, :on_error, fn ->
        ref = make_ref()
        fn _ -> {:on_error, ref} end
      end),
      Keyword.get_lazy(attrs, :steps, fn -> [step()] end)
    )
  end
end
