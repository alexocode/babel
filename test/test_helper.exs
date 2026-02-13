telemetry_started? =
  match?({:ok, _}, Application.ensure_all_started(:telemetry))

exclusions = [:skip] ++ if(telemetry_started?, do: [], else: [:telemetry])
ExUnit.start(exclude: exclusions)
