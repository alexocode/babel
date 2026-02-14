# Babel
[![CI](https://github.com/alexocode/babel/actions/workflows/ci.yml/badge.svg)](https://github.com/alexocode/babel/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/alexocode/babel/badge.svg?branch=main)](https://coveralls.io/github/alexocode/babel?branch=main)
[![Hexdocs.pm](https://img.shields.io/badge/hexdocs-online-blue)](https://hexdocs.pm/babel/)
[![Hex.pm](https://img.shields.io/hexpm/v/babel.svg)](https://hex.pm/packages/babel)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/babel)](https://hex.pm/packages/babel)

Data transformations made easy.

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Installation](#installation)
- [Usage](#usage)
  - [Private Context](#private-context)
  - [Error Reporting](#error-reporting)
  - [Telemetry](#telemetry)
- [Contributing](#contributing)

## Installation

Simply add `babel` to your list of dependencies in your `mix.exs`:

```elixir
def deps do
  [
    {:babel, "~> 1.0"}
  ]
end
```

Differences between the versions are explained in [the Changelog](./CHANGELOG.md).

Documentation gets generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and can be viewed at [HexDocs][hexdocs].

## Usage

`Babel` was born out of a desire to simplify non-trivial data transformation pipelines.
To focus on the "happy path" instead of having to write a bunch of boilerplate error handling code.

But don't listen to me, take a look for yourself:

```elixir
pipeline =
  Babel.begin()
  |> Babel.fetch(["some", "nested", "path"])
  |> Babel.map(Babel.into(%{atom_key: Babel.fetch("string-key")}))

data = %{
  "some" => %{
    "nested" => %{
      "path" => [
        %{"string-key" => :value2},
        %{"string-key" => :value2},
        %{"string-key" => :value2}
      ]
    }
  }
}

Babel.apply(pipeline, data)
=> {:ok, [
   %{atom_key: :value1},
   %{atom_key: :value2},
   %{atom_key: :value3}
]}
```

### Private Context

The `Babel.Context` includes a `private` field for passing metadata through your pipeline without affecting the transformed data. This is useful for session IDs, authentication tokens, request metadata, or any context that steps need to share.

Steps can update the private context by returning a three-tuple `{:ok, data, private}`:

```elixir
# Step 1: Set session info in private context
authenticate = Babel.then(fn credentials ->
  # Validate credentials...
  session = %{user_id: 123, session_id: "abc-xyz"}
  {:ok, credentials, session_id: session.session_id, user_id: session.user_id}
end)

# Step 2: Access private context in subsequent step
check_permissions = Babel.then(fn data ->
  # Custom step implementation can access the full context
  # using Babel.Test.ContextStep pattern or custom Step behavior
  {:ok, data}
end)

pipeline = Babel.chain(authenticate, check_permissions)
```

The private context accepts either a map or keyword list:

```elixir
# Using map
{:ok, data, %{session_id: "abc", user_id: 123}}

# Using keyword list (converted to map internally)
{:ok, data, session_id: "abc", user_id: 123}
```

Private values from multiple steps are merged together, with later values overwriting earlier ones for the same keys. The private context is passed to each step via `Babel.Context`, but is not included in the final `Babel.apply/2` result — it remains internal pipeline state.

### Error Reporting

Since you'll most likely build non-trivial transformation pipelines with `Babel` - which can fail at any given step - `Babel` ships with elaborate error reporting:

```elixir
pipeline =
  Babel.begin()
  |> Babel.fetch(["some", "nested", "path"])
  |> Babel.map(Babel.into(%{atom_key: Babel.fetch("string-key")}))

data = %{
  "some" => %{
    "nested" => %{
      "path" => [
        %{"unexpected-key" => :value1},
        %{"unexpected-key" => :value2},
        %{"unexpected-key" => :value3}
      ]
    }
  }
}

Babel.apply!(pipeline, data)
```

Which will produce the following error:

```
** (Babel.Error) Failed to transform data: [not_found: "string-key", not_found: "string-key", not_found: "string-key"]

Root Cause(s):
1. Babel.Trace<ERROR>{
  data = %{"unexpected-key" => :value1}

  Babel.fetch("string-key")
  |=> {:error, {:not_found, "string-key"}}
}
2. Babel.Trace<ERROR>{
  data = %{"unexpected-key" => :value2}

  Babel.fetch("string-key")
  |=> {:error, {:not_found, "string-key"}}
}
3. Babel.Trace<ERROR>{
  data = %{"unexpected-key" => :value3}

  Babel.fetch("string-key")
  |=> {:error, {:not_found, "string-key"}}
}

Full Trace:
Babel.Trace<ERROR>{
  data = %{"some" => %{"nested" => %{"path" => [%{"unexpected-key" => :value1}, %{"unexpected-key" => :value2}, %{"unexpected-key" => :value3}]}}}

  Babel.Pipeline<>
  |
  | Babel.fetch(["some", "nested", "path"])
  | |=< %{"some" => %{"nested" => %{"path" => [%{"unexpected-key" => :value1}, %{...}, ...]}}}
  | |=> [%{"unexpected-key" => :value1}, %{"unexpected-key" => :value2}, %{"unexpected-key" => :value3}]
  |
  | Babel.map(Babel.into(%{atom_key: Babel.fetch("string-key")}))
  | |=< [%{"unexpected-key" => :value1}, %{"unexpected-key" => :value2}, %{"unexpected-key" => :value3}]
  | |
  | | Babel.into(%{atom_key: Babel.fetch("string-key")})
  | | |=< %{"unexpected-key" => :value1}
  | | |
  | | | Babel.fetch("string-key")
  | | | |=< %{"unexpected-key" => :value1}
  | | | |=> {:error, {:not_found, "string-key"}}
  | | |
  | | |=> {:error, [not_found: "string-key"]}
  | |
  | | Babel.into(%{atom_key: Babel.fetch("string-key")})
  | | |=< %{"unexpected-key" => :value2}
  | | |
  | | | Babel.fetch("string-key")
  | | | |=< %{"unexpected-key" => :value2}
  | | | |=> {:error, {:not_found, "string-key"}}
  | | |
  | | |=> {:error, [not_found: "string-key"]}
  | |
  | | Babel.into(%{atom_key: Babel.fetch("string-key")})
  | | |=< %{"unexpected-key" => :value3}
  | | |
  | | | Babel.fetch("string-key")
  | | | |=< %{"unexpected-key" => :value3}
  | | | |=> {:error, {:not_found, "string-key"}}
  | | |
  | | |=> {:error, [not_found: "string-key"]}
  | |
  | |=> {:error, [not_found: "string-key", not_found: "string-key", not_found: "string-key"]}
  |
  |=> {:error, [not_found: "string-key", not_found: "string-key", not_found: "string-key"]}
}
```

`Babel` achieves this by keeping track of all applied steps in a `Babel.Trace` struct.
Rendering of a `Babel.Trace` is done through a custom `Inspect` implementation.

You have to this information everywhere: in the `Babel.Error` message, in `iex`, and whenever you `inspect` a `Babel.Error` or `Babel.Trace`.

### Telemetry

Babel integrates with [`:telemetry`](https://hex.pm/packages/telemetry) to emit span events for every step and pipeline execution. `:telemetry` is an **optional dependency** — when it's not installed, the telemetry calls are no-ops and Babel remains dependency-free.

To enable telemetry, add `:telemetry` to your dependencies:

```elixir
def deps do
  [
    {:babel, "~> 1.0"},
    {:telemetry, "~> 0.4 or ~> 1.0"}
  ]
end
```

#### Events

Babel emits the following [`telemetry:span/3`](https://hexdocs.pm/telemetry/telemetry.html#span/3) events:

| Event | Description |
|-------|-------------|
| `[:babel, :step, :start]` | Emitted when a step begins execution |
| `[:babel, :step, :stop]` | Emitted when a step completes |
| `[:babel, :step, :exception]` | Emitted when a step raises an unrescued exception |
| `[:babel, :pipeline, :start]` | Emitted when a pipeline begins execution |
| `[:babel, :pipeline, :stop]` | Emitted when a pipeline completes |
| `[:babel, :pipeline, :exception]` | Emitted when a pipeline raises an unrescued exception |

#### Metadata

**Start event metadata:**

| Key | Value |
|-----|-------|
| `babel` | The step or pipeline struct being executed |
| `input` | The `Babel.Context` passed as input |

**Stop event metadata:**

| Key | Value |
|-----|-------|
| `babel` | The step or pipeline struct that was executed |
| `input` | The `Babel.Context` that was passed as input |
| `trace` | The resulting `Babel.Trace` |
| `result` | `:ok` or `:error` |

#### Example

```elixir
:telemetry.attach(
  "babel-logger",
  [:babel, :pipeline, :stop],
  fn _event, %{duration: duration}, %{babel: babel, result: result}, _config ->
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)
    IO.puts("[Babel] #{inspect(babel)} completed in #{duration_ms}ms (#{result})")
  end,
  nil
)
```

## Contributing

Contributions are always welcome but please read [our contribution guidelines](./CONTRIBUTING.md) before doing so.

[hex]: https://hex.pm/packages/babel
[hexdocs]: https://hexdocs.pm/babel
