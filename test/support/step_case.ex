defmodule Babel.Test.StepCase do
  use ExUnit.CaseTemplate

  import Kernel, except: [apply: 2]

  using do
    quote do
      import Kernel, except: [apply: 2]
      import Babel.Test.StepCase
    end
  end

  def trace(step, data), do: Babel.trace(step, data)

  def apply(step, data) do
    step
    |> trace(data)
    |> Babel.Trace.result()
  end

  def apply!(step, data) do
    {:ok, value} = apply(step, data)
    value
  end
end
