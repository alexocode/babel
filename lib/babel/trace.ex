defmodule Babel.Trace do
  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(input, output) :: %__MODULE__{
          babel: Babel.t(input, output),
          data: Babel.data(),
          result: Babel.result(output),
          nested: [t]
        }
  defstruct babel: nil,
            data: nil,
            result: nil,
            nested: []

  @spec apply(babel :: Babel.t(input, output), data :: Babel.data()) :: t(input, output)
        when input: any, output: any
  def apply(babel, data) do
    # TODO: Consider checking if the result is {:error, Babel.Error.t} and extract the contained trace.
    #       This can happen when someone does `Babel.then(fn data -> Babel.apply(<babel>, data) end)`;
    #       maybe also print a warning
    {nested, result} = Babel.Applicable.apply(babel, data)

    %__MODULE__{
      babel: babel,
      data: data,
      result: result,
      nested: nested
    }
  end

  @spec ok?(t) :: boolean
  def ok?(%__MODULE__{result: result}), do: match?({:ok, _}, result)
end
