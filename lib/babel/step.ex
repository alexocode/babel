defmodule Babel.Step do
  import Kernel, except: [apply: 2]

  @type t :: t()
  @type t(output) :: t(term, output)
  @type t(input, output) :: %__MODULE__{
          name: name(),
          function: func(input, output)
        }
  defstruct [:function, :name]

  @typedoc "A term describing what this step does"
  @type name :: Babel.name()

  @type func :: func(any, any)
  @type func(input, output) :: (input -> Babel.result(output) | Babel.Applicable.result(output))

  defguard is_step_function(function) when is_function(function, 1)

  @spec new(name, func(input, output)) :: t(input, output) when input: any, output: any
  def new(name, function) when is_function(function, 1) do
    %__MODULE__{name: name, function: function}
  end

  @spec apply(t(input, output), Babel.data()) :: Babel.Applicable.result(output)
        when input: any, output: any
  def apply(%__MODULE__{function: function}, data) do
    Babel.Utils.safe_apply(function, data)
  end

  defimpl Babel.Applicable do
    defdelegate apply(step, data), to: Babel.Step
  end
end
