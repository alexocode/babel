defprotocol Babel.Applicable do
  @type t :: t(any)
  @type t(output) :: t(any, output)
  @type t(_input, _output) :: any

  @spec apply(t(input, output), Babel.data()) :: {:ok, output} | {:error, Babel.Error.t()}
        when input: Babel.data(), output: any
  def apply(t, data)
end
