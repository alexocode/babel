defmodule Babel.Step do
  import Kernel, except: [apply: 2]

  alias Babel.Utils

  @type t :: t()
  @type t(output) :: t(term, output)
  @type t(input, output) :: %__MODULE__{
          name: name(),
          function: fun(input, output)
        }
  defstruct [:function, :name]

  @typedoc "A term describing what this step does"
  @type name :: Babel.name()

  @type fun :: fun(any, any)
  @type fun(input, output) :: (input -> Babel.result(output) | Babel.Applicable.result(output))

  defguard is_step_function(function) when is_function(function, 1)

  @spec new(name, fun(input, output)) :: t(input, output) when input: any, output: any
  def new(name, function) when is_function(function, 1) do
    %__MODULE__{name: name, function: function}
  end

  @spec apply(t(input, output), Babel.data()) :: Babel.Applicable.result(output)
        when input: any, output: any
  def apply(%__MODULE__{} = step, data) do
    case step.function.(data) do
      {traces, result} when is_list(traces) ->
        {traces, Utils.resultify(result)}

      result ->
        {[], Utils.resultify(result)}
    end
  rescue
    exception -> {[], {:error, exception}}
  end

  defimpl Babel.Applicable do
    defdelegate apply(step, data), to: Babel.Step
  end
end
