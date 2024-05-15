defmodule Babel.Test do
  @moduledoc """
  You can use this module to test your custom `Babel.Step`s.

  It defines two functions:
  - `apply/2`
  - `apply!/2`

  The difference to `Babel.apply/2` and `Babel.apply!/2` is that they return
  the "raw" result from the step, including in an error case (nothing gets
  wrapped in a `Babel.Error`).

  `apply!/2` raises by `assert`ing on the `{:ok, value}` shape of the `apply/2` result.
  """
  import ExUnit.Assertions
  import Kernel, except: [apply: 2]

  @dialyzer {:nowarn_function, apply!: 2}

  def apply(step, data) do
    step
    |> Babel.trace(data)
    |> Babel.Trace.result()
  end

  def apply!(step, data) do
    assert {:ok, value} = apply(step, data)
    value
  end
end
