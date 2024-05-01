defmodule Babel.Pipeline.OnError do
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

  @spec apply(t(output), Babel.Error.t()) :: Babel.Applicable.result(output) when output: any
  def apply(%__MODULE__{handler: handler}, %Babel.Error{} = error) do
    Babel.Utils.safe_apply(handler, error)
  end

  defimpl Babel.Applicable do
    defdelegate apply(on_error, data), to: Babel.Pipeline.OnError
  end
end
