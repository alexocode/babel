defmodule Babel.Builtin do
  @moduledoc false

  alias Babel.Step

  @builtin [
    Step.Call,
    Step.Cast,
    Step.Const,
    Step.Fail,
    Step.Fetch,
    Step.FlatMap,
    Step.Get,
    Step.Identity,
    Step.Into,
    Step.Map,
    Step.Match,
    Step.Then,
    Step.Try
  ]

  @builtin_names Enum.map(@builtin, fn module ->
                   name =
                     module
                     |> Module.split()
                     |> List.last()
                     |> Macro.underscore()
                     |> String.to_atom()

                   {module, name}
                 end)

  defguard is_builtin(step) when is_struct(step) and step.__struct__ in @builtin
  defguard is_builtin_name(atom) when is_atom(atom) and unquote(Keyword.values(@builtin_names))

  def builtin?(thing), do: is_builtin(thing)

  def name_of_builtin!(%module{}) when module in @builtin do
    @builtin_names[module]
  end

  def module_of_builtin!(name) when is_builtin_name(name) do
    Enum.find_value(@builtin_names, fn
      {module, ^name} -> module
      _ -> nil
    end)
  end

  def inspect(%module{} = builtin, fields, opts) when module in @builtin do
    import Inspect.Algebra

    args = Enum.map(fields, &Map.fetch!(builtin, &1))

    color(
      concat([
        color("Babel", :atom, opts),
        ".",
        to_string(name_of_builtin!(builtin)),
        container_doc("(", args, ")", opts, &to_doc(&1, &2))
      ]),
      :call,
      opts
    )
  end
end
