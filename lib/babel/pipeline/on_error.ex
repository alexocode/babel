defmodule Babel.Pipeline.OnError do
  require Babel.Utils

  @type t :: t(any)
  @type t(output) :: %__MODULE__{
          handler: Babel.Pipeline.on_error(output)
        }
  defstruct [:handler]

  @spec new(nil) :: nil
  def new(nil), do: nil

  @spec new(on_error :: Babel.Pipeline.on_error(output)) :: t(output) when output: any
  def new(on_error) when is_function(on_error, 1) do
    %__MODULE__{handler: on_error}
  end

  @spec recover(t(output), Babel.Error.t()) :: Babel.Trace.t(output) when output: any
  def recover(%__MODULE__{} = on_error, %Babel.Error{} = error) do
    trace = %Babel.Trace{babel: on_error, input: error.trace.output}

    maybe_nested_trace =
      Babel.Utils.trace_try do
        on_error.handler.(error)
      end

    case maybe_nested_trace do
      %Babel.Trace{} = nested ->
        %Babel.Trace{trace | output: nested.output, nested: [nested]}

      result ->
        %Babel.Trace{trace | output: result}
    end
  end
end
