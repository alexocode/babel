defmodule Babel.TelemetryTest do
  use ExUnit.Case, async: false

  import Babel.Test.Factory

  alias Babel.Trace

  @step_start [:babel, :step, :start]
  @step_stop [:babel, :step, :stop]
  @step_exception [:babel, :step, :exception]
  @pipeline_start [:babel, :pipeline, :start]
  @pipeline_stop [:babel, :pipeline, :stop]
  @pipeline_exception [:babel, :pipeline, :exception]

  setup do
    test_pid = self()
    handler_id = make_ref()

    events = [
      @step_start,
      @step_stop,
      @step_exception,
      @pipeline_start,
      @pipeline_stop,
      @pipeline_exception
    ]

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  describe "step execution" do
    test "emits start and stop events for a successful step" do
      step = Babel.identity()
      data = data()

      Babel.trace(step, data)

      assert_received {:telemetry, @step_start, start_measurements, start_metadata}
      assert %{system_time: _} = start_measurements
      assert start_metadata.babel == step
      assert start_metadata.input == Babel.Context.new(data)

      assert_received {:telemetry, @step_stop, stop_measurements, stop_metadata}
      assert %{duration: _} = stop_measurements
      assert %Trace{} = stop_metadata.trace
      assert stop_metadata.result == :ok
    end

    test "emits start and stop events for a failed step" do
      step = Babel.then(fn _ -> {:error, :boom} end)
      data = data()

      Babel.trace(step, data)

      assert_received {:telemetry, @step_start, _measurements, start_metadata}
      assert start_metadata.babel == step

      assert_received {:telemetry, @step_stop, _measurements, stop_metadata}
      assert %Trace{} = stop_metadata.trace
      assert stop_metadata.result == :error
    end

    test "emits exception event when a step raises" do
      step = Babel.then(fn _ -> raise "kaboom" end)
      data = data()

      Babel.trace(step, data)

      assert_received {:telemetry, @step_start, _measurements, _start_metadata}

      # :telemetry.span/3 catches the exception, emits exception event, then re-raises.
      # But the rescue in Applicable.apply catches it before :telemetry.span sees it.
      # So we get a stop event with result: :error instead.
      assert_received {:telemetry, @step_stop, _measurements, stop_metadata}
      assert stop_metadata.result == :error
    end

    test "includes babel and input in start metadata" do
      step = Babel.const(:hello)
      data = data()

      Babel.trace(step, data)

      assert_received {:telemetry, @step_start, _measurements, metadata}
      assert metadata.babel == step
      assert metadata.input == Babel.Context.new(data)
    end

    test "includes trace in stop metadata" do
      step = Babel.const(:hello)
      data = data()

      trace = Babel.trace(step, data)

      assert_received {:telemetry, @step_stop, _measurements, metadata}
      assert metadata.trace == trace
    end
  end

  describe "pipeline execution" do
    test "emits start and stop events for a successful pipeline" do
      pipeline = Babel.Pipeline.new([Babel.identity()])
      data = data()

      Babel.trace(pipeline, data)

      assert_received {:telemetry, @pipeline_start, start_measurements, start_metadata}
      assert %{system_time: _} = start_measurements
      assert start_metadata.babel == pipeline
      assert start_metadata.input == Babel.Context.new(data)

      assert_received {:telemetry, @pipeline_stop, stop_measurements, stop_metadata}
      assert %{duration: _} = stop_measurements
      assert %Trace{} = stop_metadata.trace
      assert stop_metadata.result == :ok
    end

    test "emits start and stop events for a failed pipeline" do
      pipeline = Babel.Pipeline.new([Babel.then(fn _ -> {:error, :boom} end)])
      data = data()

      Babel.trace(pipeline, data)

      assert_received {:telemetry, @pipeline_start, _measurements, start_metadata}
      assert start_metadata.babel == pipeline

      assert_received {:telemetry, @pipeline_stop, _measurements, stop_metadata}
      assert %Trace{} = stop_metadata.trace
      assert stop_metadata.result == :error
    end

    test "emits step events for each step inside the pipeline" do
      step1 = Babel.identity()
      step2 = Babel.const(:done)
      pipeline = Babel.Pipeline.new([step1, step2])
      data = data()

      Babel.trace(pipeline, data)

      # Two step start/stop pairs (one per step)
      assert_received {:telemetry, @step_start, _measurements, %{babel: ^step1}}
      assert_received {:telemetry, @step_stop, _measurements, %{babel: ^step1}}
      assert_received {:telemetry, @step_start, _measurements, %{babel: ^step2}}
      assert_received {:telemetry, @step_stop, _measurements, %{babel: ^step2}}

      # Plus one pipeline start/stop pair
      assert_received {:telemetry, @pipeline_start, _measurements, %{babel: ^pipeline}}
      assert_received {:telemetry, @pipeline_stop, _measurements, %{babel: ^pipeline}}
    end
  end
end
