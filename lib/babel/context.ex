defmodule Babel.Context do
  @moduledoc """
  Passed to `Babel.Applicable.apply/2` wrapping the given `data`.

  In addition it retains a `history` of all previously executed steps by
  capturing their `Babel.Trace`s.

  The `private` field is a map that can be used to pass metadata through
  the pipeline without affecting the transformed data itself. Steps can
  update the private context by returning `{:ok, data, private}`.
  """
  @type t :: t(any)
  @type t(data) :: %__MODULE__{
          data: data,
          history: [Babel.Trace.t()],
          private: map()
        }
  defstruct [:data, {:history, []}, {:private, %{}}]

  @spec new(data) :: t(data) when data: Babel.data()
  @spec new(data, history :: [Babel.Trace.t()]) :: t(data) when data: Babel.data()
  @spec new(data, history :: [Babel.Trace.t()], private :: map()) :: t(data)
        when data: Babel.data()
  def new(data, history \\ [], private \\ %{}) do
    %__MODULE__{data: data, history: history, private: private}
  end
end
