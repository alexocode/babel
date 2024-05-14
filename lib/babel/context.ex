defmodule Babel.Context do
  @moduledoc """
  Passed to `Babel.Applicable.apply/2` wrapping the given `data`.

  In addition it retains a `history` of all previously executed steps by
  capturing their `Babel.Trace`s.
  """
  @type t :: t(any)
  @type t(data) :: %__MODULE__{
          data: data,
          history: [Babel.Trace.t()]
        }
  defstruct [:data, {:history, []}]

  @spec new(data) :: t(data) when data: Babel.data()
  @spec new(data, history :: [Babel.Trace.t()]) :: t(data) when data: Babel.data()
  def new(data, history \\ []) do
    %__MODULE__{data: data, history: history}
  end
end
