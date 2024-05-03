defmodule Babel.Trace do
  require Babel.Core
  require Babel.Logger

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

  @spec find(t, spec_or_path :: spec | nonempty_list(spec)) :: [t]
        when spec: Babel.t() | Babel.Core.name_with_args() | Babel.Core.name()
  def find(%__MODULE__{} = trace, spec_path) when is_list(spec_path) do
    Enum.reduce(spec_path, [trace], fn spec, traces ->
      Enum.flat_map(traces, &find(&1, spec))
    end)
  end

  def find(%__MODULE__{} = trace, {atom, arg} = spec)
      when Babel.Core.is_core_name(atom) and not is_list(arg) do
    case do_find(trace, spec) do
      [] ->
        Babel.Logger.warning(
          "To find a built-in step the second argument of `#{inspect(spec)}` needs to be a list."
        )

        []

      traces ->
        traces
    end
  end

  def find(%__MODULE__{} = trace, spec), do: do_find(trace, spec)

  defp do_find([], _babel), do: []
  defp do_find([trace | traces], spec), do: do_find(trace, spec) ++ do_find(traces, spec)

  defp do_find(trace, spec) do
    if matches_spec?(trace.babel, spec) do
      [trace | do_find(trace.nested, spec)]
    else
      do_find(trace.nested, spec)
    end
  end

  def matches_spec?(babel, babel), do: true
  def matches_spec?(%{name: name}, name), do: true
  def matches_spec?(%{name: {name, _args}}, name), do: true
  def matches_spec?(_babel, _spec), do: false
end
