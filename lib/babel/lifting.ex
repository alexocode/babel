defmodule Babel.Lifting do
  @moduledoc false

  @type t :: t(any, term)
  @type t(input, output) :: Babel.Step.t(input, output) | Babel.Pipeline.t(input, output)

  @type pipeline() :: pipeline(term)
  @type pipeline(output) :: Babel.Pipeline.t(output)

  alias Babel.{Pipeline, Step}

  require Step

  defmacro deflifted(call, from: module) do
    {name, [babel | args]} = name_and_args(call)

    doc = """
    Wraps `#{inspect(module)}.#{name}/#{1 + length(args)}` in a `Babel.Step` and
    appends it after the given pipeline or step.

    Basically equivalent to:

        Babel.Pipeline.chain(babel, Babel.Step.wrap(#{inspect(module)}, #{inspect(name)}, #{inspect(args)}))

    See the moduledoc for further details.
    """

    quote location: :keep do
      @doc unquote(doc)
      def unquote(call) do
        unquote(__MODULE__).wrap_and_chain(
          unquote(babel),
          {unquote(module), unquote(name), unquote(args)}
        )
      end
    end
  end

  defp name_and_args({:when, _, [call | _guards]}) do
    name_and_args(call)
  end

  defp name_and_args({name, _, args}) do
    {name, without_defaults!(name, args)}
  end

  defp without_defaults!(name, args) do
    Enum.each(args, fn
      {:\\, _, [_var | _]} = default ->
        raise ArgumentError,
              "default found where none expected(#{name}): " <> Macro.to_string(default)

      _ ->
        :ok
    end)

    args
  end

  @doc false
  @spec wrap_and_chain(t, {module, atom, list}) :: pipeline()
  def wrap_and_chain(babel, {module, func_name, args})
      when is_atom(module) and is_atom(func_name) and is_list(args) do
    wrapped = Step.new({module, func_name}, &apply(Elixir.Enum, func_name, [&1 | args]))

    Babel.chain(babel, wrapped)
  end
end
