defmodule Babel.Context do
  @type t :: t(any)
  @type t(data) :: %__MODULE__{
          data: data,
          original: Babel.data()
        }
  defstruct [:data, :original]

  @spec new(data) :: t(data) when data: Babel.data()
  def new(data) do
    %__MODULE__{data: data, original: data}
  end
end
