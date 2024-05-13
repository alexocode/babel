defmodule Babel.Pipeline.OnError do
  alias Babel.Error
  alias Babel.Pipeline
  alias Babel.Trace

  require Babel.Trace.Nesting

  @type t :: t(any)
  @type t(output) :: %__MODULE__{
          handler: Pipeline.on_error(output)
        }
  defstruct [:handler]

  @spec new(nil) :: nil
  def new(nil), do: nil

  @spec new(on_error :: Pipeline.on_error(output)) :: t(output) when output: any
  def new(on_error) when is_function(on_error, 1) do
    %__MODULE__{handler: on_error}
  end

  @spec recover(t(output), Error.t()) :: Trace.t(output) when output: any
  def recover(%__MODULE__{handler: handler} = on_error, %Error{} = error) do
    Trace.Nesting.traced_try on_error, error.trace.output do
      handler.(error)
    end
  end
end
