defprotocol Babel.Applicable do
  @moduledoc """
  The protocol which enables `Babel.apply/2`.

  Any custom `Babel.Step` will have to implement this protocol. It's suggested
  to `use Babel.Step` as that will derive an implementation. See `Babel.Step`
  for further details.
  """

  alias Babel.Trace

  @type t :: t(any)
  @type t(output) :: t(any, output)
  @type t(_input, _output) :: any

  @spec apply(t(input, output), Babel.data()) :: Trace.t(output)
        when input: Babel.data(), output: any
  def apply(t, data)
end
