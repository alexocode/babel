defprotocol Babel.Applicable do
  @type t :: t(any)
  @type t(output) :: t(any, output)
  @type t(_input, _output) :: any

  @type result :: result(any)
  @type result(output) :: {[Babel.Trace.t()], Babel.result(output)}

  @spec apply(t(input, output), Babel.data()) :: result(output)
        when input: Babel.data(), output: any
  def apply(t, data)
end
