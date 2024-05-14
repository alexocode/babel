defmodule Babel.PipelineTest do
  use ExUnit.Case, async: true

  import Babel.Test.Factory
  import Kernel, except: [apply: 2]

  alias Babel.Error
  alias Babel.Pipeline
  alias Babel.Trace

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
  end

  describe "apply/2" do
    test "without any steps returns the given data as is" do
      pipeline = pipeline(steps: [])
      data = data()

      assert apply(pipeline, data) == %Trace{
               babel: pipeline,
               input: data,
               output: {:ok, data}
             }
    end

    test "applies all steps sequentially" do
      step1 = step(&[:step1 | &1])
      step2 = step(&[:step2 | &1])
      step3 = step(&[:step3 | &1])
      step4 = step(&[:step4 | &1])

      pipeline = pipeline(steps: [step1, step2, step3, step4])
      data = [:begin]

      assert %Trace{} = trace = apply(pipeline, data)
      assert trace.babel == pipeline
      assert trace.input == data
      assert {:ok, list} = trace.output

      assert list == [:step4, :step3, :step2, :step1, :begin]

      assert trace.nested == [
               trace_after([], step1, data),
               trace_after([step1], step2, data),
               trace_after([step1, step2], step3, data),
               trace_after([step1, step2, step3], step4, data)
             ]
    end

    test "applies nested pipelines sequentially" do
      step1 =
        pipeline(steps: [step(&[{:pipeline1, :step1} | &1]), step(&[{:pipeline1, :step2} | &1])])

      step2 = pipeline(steps: [step(&[{:pipeline2, :step1} | &1])])
      step3 = step(&[:step3 | &1])

      pipeline = pipeline(steps: [step1, step2, step3])
      data = [:begin]

      assert %Trace{} = trace = apply(pipeline, data)
      assert trace.babel == pipeline
      assert trace.input == data
      assert {:ok, list} = trace.output

      assert list == [
               :step3,
               {:pipeline2, :step1},
               {:pipeline1, :step2},
               {:pipeline1, :step1},
               :begin
             ]

      assert trace.nested == [
               trace_after([], step1, data),
               trace_after([step1], step2, data),
               trace_after([step1, step2], step3, data)
             ]
    end

    test "aborts the pipeline as soon as the first error occurs" do
      step1 = step(&[:step1 | &1])
      step2 = step(&{:error, &1})
      step3 = step(fn _ -> :never_applied end)

      pipeline = pipeline(steps: [step1, step2, step3], on_error: nil)
      data = [:begin]

      assert %Trace{} = trace = apply(pipeline, data)
      assert trace.babel == pipeline
      assert trace.input == data
      assert trace.output == {:error, [:step1, :begin]}

      assert trace.nested == [
               trace_after([], step1, data),
               trace_after([step1], step2, data)
             ]
    end

    test "calls on_error when an error occurs" do
      step1 = step(&[:step1 | &1])
      step2 = step(&{:error, &1})
      step3 = step(fn _ -> :never_applied end)

      pipeline =
        pipeline(
          steps: [step1, step2, step3],
          on_error: fn %Error{reason: list} -> [:on_error | list] end
        )

      data = [:begin]

      assert %Trace{} = trace = apply(pipeline, data)
      assert trace.babel == pipeline
      assert trace.input == data
      assert trace.output == {:ok, [:on_error, :step1, :begin]}

      assert trace.nested == [
               trace_after([], step1, data),
               trace_after([step1], step2, data),
               trace_for_on_error(pipeline, data)
             ]
    end
  end

  describe "chain/2" do
    test "merges pipelines when at least one is unnamed and without error handling" do
      name = {:test_pipeline, make_ref()}
      on_error = fn _ -> name end

      pipeline1 = pipeline(name: name, on_error: on_error)
      pipeline2 = pipeline(name: nil, on_error: nil)

      assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
               pipeline1
               | reversed_steps: pipeline2.reversed_steps ++ pipeline1.reversed_steps
             }

      pipeline1 = pipeline(name: nil, on_error: nil)
      pipeline2 = pipeline(name: name, on_error: on_error)

      assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
               pipeline2
               | reversed_steps: pipeline2.reversed_steps ++ pipeline1.reversed_steps
             }

      pipeline1 = pipeline(name: nil, on_error: on_error)
      pipeline2 = pipeline(name: name, on_error: nil)

      assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
               name: pipeline2.name,
               on_error: pipeline1.on_error,
               reversed_steps: pipeline2.reversed_steps ++ pipeline1.reversed_steps
             }

      pipeline1 = pipeline(name: name, on_error: nil)
      pipeline2 = pipeline(name: nil, on_error: on_error)

      assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
               name: pipeline1.name,
               on_error: pipeline2.on_error,
               reversed_steps: pipeline2.reversed_steps ++ pipeline1.reversed_steps
             }
    end

    test "merges pipelines when they have equal names and at least one has no error handling" do
      name = {:test_pipeline, make_ref()}
      on_error = fn _ -> name end

      pipeline1 = pipeline(name: name, on_error: on_error)
      pipeline2 = pipeline(name: name, on_error: nil)

      assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
               pipeline1
               | reversed_steps: pipeline2.reversed_steps ++ pipeline1.reversed_steps
             }

      pipeline1 = pipeline(name: name, on_error: nil)
      pipeline2 = pipeline(name: name, on_error: on_error)

      assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
               pipeline2
               | reversed_steps: pipeline2.reversed_steps ++ pipeline1.reversed_steps
             }
    end

    test "includes the chained pipeline in the steps when name or on_error do not match" do
      non_merge_combinations = [
        {pipeline(), pipeline()},
        {pipeline(name: nil), pipeline()},
        {pipeline(), pipeline(name: nil)},
        {pipeline(name: :test), pipeline(name: :test)},
        {pipeline(), pipeline(on_error: nil)},
        {pipeline(on_error: nil), pipeline()},
        {pipeline(on_error: &Function.identity/1), pipeline(on_error: &Function.identity/1)}
      ]

      for {pipeline1, pipeline2} <- non_merge_combinations do
        assert Pipeline.chain(pipeline1, pipeline2) == %Pipeline{
                 pipeline1
                 | reversed_steps: [pipeline2 | pipeline1.reversed_steps]
               }
      end
    end

    test "includes the given list of steps in the current pipeline" do
      pipeline = pipeline()
      steps = [step(), step(), step()]

      assert Pipeline.chain(pipeline, steps) == %Pipeline{
               pipeline
               | reversed_steps: Enum.reverse(steps) ++ pipeline.reversed_steps
             }
    end
  end

  describe "on_error/2" do
    test "sets the on_error field with the given function (wrapped in Pipeline.OnError)" do
      pipeline = pipeline(on_error: nil)
      on_error = fn _ -> :BLUBB end

      assert Pipeline.on_error(pipeline, on_error) == %Pipeline{
               pipeline
               | on_error: Pipeline.OnError.new(on_error)
             }
    end

    test "overrides an already set on_error field" do
      pipeline = pipeline(on_error: fn _ -> :already_set end)
      on_error = fn _ -> :OVERRIDE! end

      assert Pipeline.on_error(pipeline, on_error) == %Pipeline{
               pipeline
               | on_error: Pipeline.OnError.new(on_error)
             }
    end
  end

  defp apply(%Pipeline{} = pipeline, %Babel.Context{} = context) do
    Pipeline.apply(pipeline, context)
  end

  defp apply(%Pipeline{} = pipeline, data) do
    Pipeline.apply(pipeline, context(data))
  end

  defp trace_after(before, babel, data) do
    trace_for(babel, Enum.reduce(before, data, &Babel.apply!/2))
  end

  defp trace_for(babel, data), do: Babel.trace(babel, data)

  defp trace_for_on_error(%Pipeline{} = pipeline, data) do
    error =
      pipeline.reversed_steps
      |> Enum.reverse()
      |> Enum.reduce_while(data, fn step, data ->
        case Babel.apply(step, data) do
          {:ok, value} -> {:cont, value}
          {:error, error} -> {:halt, error}
        end
      end)

    Pipeline.OnError.recover(pipeline.on_error, error)
  end
end
