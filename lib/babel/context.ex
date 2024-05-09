defmodule Babel.Context do
  @type t :: t(any)
  @type t(data) :: %__MODULE__{
          current: data,
          original: Babel.data()
        }
  defstruct [:current, :original]

  @spec new(data) :: t(data) when data: Babel.data()
  def new(data) do
    %__MODULE__{current: data, original: data}
  end
end
