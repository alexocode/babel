defmodule Babel.Context do
  @type t :: %__MODULE__{
          root: Babel.data(),
          current: Babel.data(),
          failed?: boolean,
          next_step: Babel.Step.t() | nil
        }
  defstruct root: nil,
            current: nil,
            failed?: false,
            next_step: nil
end
