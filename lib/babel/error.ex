defmodule Babel.Error do
  @moduledoc """
  Represents a failed `Babel.Applicable` evaluation. Contains the reason of the
  returned `{:error, <reason>}` tuple and a `Babel.Trace`.

  The message of a `Babel.Error` also displays the "root causes" of the `Babel.Trace`
  (using `Babel.Trace.root_causes/1`).

  ## Example

  Here's an example of how a `Babel.Error` message might look like:

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
        | ... OK traces omitted (1) ...
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
  """
  alias Babel.Trace

  @type t :: t(any)
  @type t(reason) :: %__MODULE__{reason: reason, trace: Trace.t()}
  defexception [:reason, :trace]

  @spec new(Trace.t({:error, reason})) :: t(reason) when reason: any
  def new(%Trace{} = trace) do
    %__MODULE__{
      reason: determine_reason(trace),
      trace: trace
    }
  end

  defp determine_reason(%Trace{} = trace) do
    trace
    |> Trace.result()
    |> determine_reason()
  end

  defp determine_reason({:error, reason}), do: determine_reason(reason)
  defp determine_reason(other_reason), do: other_reason

  @impl true
  def message(%__MODULE__{reason: reason, trace: trace}) do
    root_causes =
      trace
      |> Trace.root_causes()
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {root_cause, index} ->
        "#{index}. " <> inspect(root_cause)
      end)

    """
    Failed to transform data: #{inspect(reason)}

    Root Cause(s):
    #{root_causes}

    Full Trace:
    #{inspect(trace, custom_options: [depth: :error])}
    """
  end
end
