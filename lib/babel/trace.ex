defmodule Babel.Trace do
  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(input, output) :: %__MODULE__{
          babel: Babel.t(input, output),
          input: Babel.data(),
          output: Babel.result(output),
          nested: [t]
        }
  defstruct babel: nil,
            input: nil,
            output: nil,
            nested: []

  @spec apply(babel :: Babel.t(input, output), input :: Babel.data()) :: t(input, output)
        when input: any, output: any
  def apply(babel, data) do
    # TODO: Consider checking if the output is {:error, Babel.Error.t} and extract the contained trace.
    #       This can happen when someone does `Babel.then(fn data -> Babel.apply(<babel>, data) end)`;
    #       maybe also print a warning
    {nested, output} = Babel.Applicable.apply(babel, data)

    %__MODULE__{
      babel: babel,
      input: data,
      output: output,
      nested: nested
    }
  end

  @spec ok?(t) :: boolean
  def ok?(%__MODULE__{output: output}), do: match?({:ok, _}, output)
end
