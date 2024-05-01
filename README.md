# Babel
[![CI](https://github.com/sascha-wolf/babel/workflows/CI/badge.svg)](https://github.com/sascha-wolf/babel/actions?query=branch%3Amain+workflow%3ACI)
[![Coverage Status](https://coveralls.io/repos/github/sascha-wolf/babel/badge.svg?branch=main)](https://coveralls.io/github/sascha-wolf/babel?branch=main)
[![Hexdocs.pm](https://img.shields.io/badge/hexdocs-online-blue)](https://hexdocs.pm/babel/)
[![Hex.pm](https://img.shields.io/hexpm/v/babel.svg)](https://hex.pm/packages/babel)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/babel)](https://hex.pm/packages/babel)

TODO

[See the documentation](https://hexdocs.pm/babel) for more information.

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Installation](#installation)
- [Usage](#usage)
  - [Error Reporting](#error-reporting)
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

data =
  %{
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

iex> Babel.apply(pipeline, data)
{:ok,
 [
   %{atom_key: :value1},
   %{atom_key: :value2},
   %{atom_key: :value3}
 ]}
```

### Error Reporting

Since you'll most likely build non-trivial transformation pipelines with `Babel` - which can fail at any given step - `Babel` ships with elaborate error reporting:

<details>
<summary>Example</summary>

```elixir
pipeline =
  Babel.begin()
  |> Babel.fetch(["some", "nested", "path"])
  |> Babel.map(Babel.into(%{atom_key: Babel.fetch("string-key")}))

data =
  %{
    "some" => %{
      "nested" => %{
        "path" => [
          %{"unexpected-key" => :value2},
          %{"unexpected-key" => :value2},
          %{"unexpected-key" => :value2}
        ]
      }
    }
  }

iex> Babel.apply(pipeline, data)
{
  :error,
  %Babel.Error{
   reason: [
     not_found: "string-key",
     not_found: "string-key",
     not_found: "string-key"
   ],
   trace: Babel.Trace<ERROR>{
      data =
        %{
         "some" => %{
           "nested" => %{
             "path" => [
               %{"unexpected-key" => :value1},
               %{"unexpected-key" => :value2},
               %{"unexpected-key" => :value2}
             ]
           }
         }
        }

      Babel.Pipeline<>
      |
      | Babel.fetch(["some", "nested", "path"])
      | |=< %{"some" => %{"nested" => %{"path" => [%{"unexpected-key" => :value1, ...}, %{...}, ...]}}}
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
  }
}
```

</details>

`Babel` achieves this through a custom implementation of the `Inspect` protocol for `Babel.Trace`.
As such you'll have access to them everywhere; in the `Babel.Error` message, in `iex`, and whenever you `inspect` a `Babel.Error` or `Babel.Trace`.

## Contributing

Contributions are always welcome but please read [our contribution guidelines](./CONTRIBUTING.md) before doing so.

[hex]: https://hex.pm/packages/babel
[hexdocs]: https://hexdocs.pm/babel
