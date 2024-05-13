defmodule Babel.Trace do
  alias Babel.Context
  alias Babel.Step

  import Babel.Builtin

  require Babel.Logger

  @type t() :: t(any, any)
  @type t(output) :: t(any, output)
  @type t(input, output) :: %__MODULE__{
          babel: Babel.t(input, output),
          input: Babel.data(),
          output: Step.result(output),
          nested: [t]
        }
  defstruct babel: nil,
            input: nil,
            output: nil,
            nested: []

  @spec new(
          babel :: Babel.t(input, output),
          input :: input | Context.t(input),
          output :: Step.result(output),
          nested :: [t]
        ) :: t(input, output)
        when input: any, output: any
  def new(babel, input, output, nested \\ [])

  def new(babel, %Context{current: input}, output, nested) do
    new(babel, input, output, nested)
  end

  def new(babel, input, output, nested) do
    %__MODULE__{
      babel: babel,
      input: input,
      output: output,
      nested: nested
    }
  end

  @spec error?(t) :: boolean
  def error?(%__MODULE__{output: output}) do
    case output do
      :error -> true
      {:error, _} -> true
      _ok -> false
    end
  end

  @spec ok?(t) :: boolean
  def ok?(%__MODULE__{} = trace), do: not error?(trace)

  @spec result(t) :: {:ok, value :: any} | {:error, reason :: any}
  def result(%__MODULE__{output: output}) do
    case output do
      :error -> {:error, :unknown}
      {:error, reason} -> {:error, reason}
      {:ok, value} -> {:ok, value}
      value -> {:ok, value}
    end
  end

  @doc """
  Returns the nested traces which caused the given trace to fail.

  To be specific it recursively checks all nested traces and collects all error
  traces which have no nested traces themselves, assuming that this implies that
  they were the root cause of the failure.
  """
  @spec root_causes(t) :: [t]
  def root_causes(%__MODULE__{} = trace) do
    find(trace, fn t ->
      error?(t) and t.nested == []
    end)
  end

  @spec find(t, function :: (t -> boolean)) :: [t]
  def find(%__MODULE__{} = trace, function) when is_function(function, 1) do
    do_find(trace, function)
  end

  @spec find(t, spec_or_path :: spec | nonempty_list(spec)) :: [t]
        when spec:
               Babel.t()
               | Babel.name()
               | (builtin_name :: atom)
               | {builtin_name :: atom, args :: [term]}
  def find(%__MODULE__{} = trace, spec_path) when is_list(spec_path) do
    Enum.reduce(spec_path, [trace], fn spec, traces ->
      Enum.flat_map(traces, &find(&1, spec))
    end)
  end

  def find(%__MODULE__{} = trace, {atom, args}) when is_builtin_name(atom) and is_list(args) do
    do_find(trace, apply(module_of_builtin!(atom), :new, args))
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

  def find(%__MODULE__{} = trace, spec), do: do_find(trace, spec)

  defp do_find(t, spec) when not is_function(spec), do: do_find(t, &matches_spec?(&1, spec))

  defp do_find([], _function), do: []
  defp do_find([t | r], f), do: do_find(t, f) ++ do_find(r, f)

  defp do_find(%__MODULE__{} = trace, function) do
    if function.(trace) do
      [trace | do_find(trace.nested, function)]
    else
      do_find(trace.nested, function)
    end
  end

  def matches_spec?(%__MODULE__{babel: babel}, spec), do: matches_spec?(babel, spec)
  def matches_spec?(babel, babel), do: true
  def matches_spec?(%{name: name}, name), do: true

  def matches_spec?(builtin, name) when is_builtin(builtin) and is_atom(name) do
    name_of_builtin!(builtin) == name
  end

  def matches_spec?(_babel, _spec), do: false
end
