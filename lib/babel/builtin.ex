defmodule Babel.Builtin do
  @moduledoc false

  @builtin [
    __MODULE__.Call,
    __MODULE__.Cast,
    __MODULE__.Const,
    __MODULE__.Fail,
    __MODULE__.Fetch,
    __MODULE__.FlatMap,
    __MODULE__.Get,
    __MODULE__.Identity,
    __MODULE__.Into,
    __MODULE__.Map,
    __MODULE__.Match,
    __MODULE__.Root,
    __MODULE__.Then,
    __MODULE__.Try
  ]

  @builtin_name_by_module Enum.map(@builtin, fn module ->
                            name =
                              module
                              |> Module.split()
                              |> List.last()
                              |> Macro.underscore()
                              |> String.to_atom()

                            {module, name}
                          end)

  defguard struct_module(thing)
           when :erlang.is_map(thing) and :erlang.is_map_key(:__struct__, thing) and
                  :erlang.map_get(:__struct__, thing)

  defguard is_builtin(step) when struct_module(step) in @builtin

  defguard is_builtin_name(atom)
           when is_atom(atom) and atom in unquote(Keyword.values(@builtin_name_by_module))

  def builtin?(thing), do: is_builtin(thing)

  # coveralls-ignore-next-line
  def builtin_names, do: unquote(Keyword.values(@builtin_name_by_module))

  def name_of_builtin!(%module{}) when module in @builtin do
    @builtin_name_by_module[module]
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
