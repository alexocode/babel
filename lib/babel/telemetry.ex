defmodule Babel.Telemetry do
  @moduledoc false

  @telemetry_loaded Code.ensure_loaded?(:telemetry)

  if @telemetry_loaded do
    def span(event_prefix, metadata, fun) do
      :telemetry.span(event_prefix, metadata, fun)
    end
  else
    def span(_event_prefix, _metadata, fun) do
      {result, _stop_metadata} = fun.()
      result
    end
  end
end
