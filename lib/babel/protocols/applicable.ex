defprotocol Babel.Applicable do
  alias Babel.Trace

  @type t :: t(any)
  @type t(output) :: t(any, output)
  @type t(_input, _output) :: any

  @spec apply(t(input, output), Babel.data()) :: Trace.t(output)
        when input: Babel.data(), output: any
  def apply(t, data)
end
