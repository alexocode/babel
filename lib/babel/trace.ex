defmodule Babel.Trace do
  import Babel.Builtin

  require Babel.Logger

  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(input, output) :: %__MODULE__{
          babel: Babel.t(input, output),
          input: Babel.data(),
          output: Babel.Step.result(output),
          nested: [t]
        }
  defstruct babel: nil,
            input: nil,
            output: nil,
            nested: []

  @spec ok?(t) :: boolean
  def ok?(%__MODULE__{output: output}) do
    case output do
      :error -> false
      {:error, _} -> false
      _ok -> true
    end
  end

  @spec result(t) :: {:ok, value :: any} | {:error, reason :: any}
  def result(%__MODULE__{output: output}) do
    case output do
      :error -> {:error, :unknown}
      {:error, reason} -> {:error, reason}
      {:ok, value} -> {:ok, value}
      value -> {:ok, value}
    end
  end

  @spec find(t, spec_or_path :: spec | nonempty_list(spec)) :: [t]
        when spec: Babel.t() | (builtin_name :: atom) | {builtin_name :: atom, args :: [term]}
  def find(%__MODULE__{} = trace, spec_path) when is_list(spec_path) do
    Enum.reduce(spec_path, [trace], fn spec, traces ->
      Enum.flat_map(traces, &find(&1, spec))
    end)
  end

  def find(%__MODULE__{} = trace, {atom, arg} = spec)
      when is_builtin_name(atom) and not is_list(arg) do
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

  def find(%__MODULE__{} = trace, {atom, args}) when is_builtin_name(atom) and is_list(args) do
    do_find(trace, apply(module_of_builtin!(atom), :new, args))
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

  def matches_spec?(builtin, name) when is_builtin(builtin) and is_atom(name) do
    name_of_builtin!(builtin) == name
  end

  def matches_spec?(_babel, _spec), do: false
end
