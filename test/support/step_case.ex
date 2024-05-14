defmodule Babel.Test.StepCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Kernel, except: [apply: 2]
      import Babel, only: [trace: 2]
      import Babel.Test
    end
  end
end
