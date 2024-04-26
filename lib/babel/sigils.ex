# if Code.ensure_loaded?(NimbleParsec) do
defmodule Babel.Sigils do
  defmodule Parsec do
    import NimbleParsec

    digit = ascii_char([?0..?9])

    integer =
      empty()
      |> times(digit, min: 1)
      |> map({String, :to_integer, []})
      |> label("integer")

    float =
      empty()
      |> repeat(digit)
      |> string(".")
      |> times(digit, min: 1)
      |> map({String, :to_float, []})
      |> label("float")

    escaped_char = fn char ->
      ascii_char([?\\]) |> ascii_char([char]) |> replace(List.to_string([char]))
    end

    # not_char_unless_escaped = fn chars ->
    #   chars = List.wrap(chars)

    #   escaped_chars =
    #     Enum.map(chars, fn char ->
    #     end)

    #   choice(
    #     escaped_chars ++
    #       [
    #         if length(chars) == 1 do
    #           ascii_char(not: )
    #         empty()
    #         |> choice(IO.inspect(Enum.map(chars, &ascii_char(not: &1))))
    #         |> lookahead_not(ascii_char(chars))
    #       ]
    #   )
    # end

    string =
      empty()
      |> string(~S'"')
      |> repeat(
        choice([
          escaped_char.(?"),
          ascii_char(not: ?")
        ])
      )
      |> string(~S'"')
      |> map({List, :to_string, []})
      |> label("string")

    alpha =
      choice([
        ascii_char([?a..?z]),
        ascii_char([?A..?Z])
      ])
      |> label("alpha character (a-z,A-Z)")

    symbol =
      alpha
      |> repeat(
        choice([
          alpha,
          digit,
          string("_")
        ])
      )
      |> map({List, :to_string, []})
      |> label("symbol")

    atom =
      empty()
      |> string(":")
      |> choice([
        string,
        symbol
      ])
      |> map({String, :to_atom, []})
      |> label("atom")

    square_brackets_segment =
      empty()
      |> ignore(string("["))
      |> choice([
        integer,
        float,
        string,
        atom
      ])
      |> ignore(string("]"))

    stop_symbols = choice([string("."), string("[")])

    bare_segment =
      empty()
      |> wrap(
        empty()
        |> debug()
        # THIS CONSUMES MORE THAN IT SHOULD
        |> times(
          choice([
            escaped_char.(?.),
            escaped_char.(?[),
            ascii_char(not: ?.)
          ]),
          min: 1
        )
        |> lookahead_not(stop_symbols)
        |> debug()
      )
      |> map({List, :to_string, []})
      |> label("bare path segment")

    segment = choice([square_brackets_segment, bare_segment])

    defparsec(
      :path,
      segment
      |> repeat(
        choice([
          ignore(string(".")) |> concat(bare_segment),
          square_brackets_segment
        ])
      )
    )
  end

  defmacro sigil_B({:<<>>, _, [string]}, _modifiers) do
    path = to_path(string)

    quote do
      Babel.Core.fetch(unquote(path))
    end
  end

  defp to_path(string) do
    Parsec.path(string) |> IO.inspect()
  end

  # @square_brackets_regex ~r/(.*?)(\[.+)\](?>(?<!\\)\.([^\[]+))*/
  # # |([^\[]+)(?>(?<!\\)\.(.+))*
  # defp to_path(string) when is_binary(string) do
  #   dbg(string)

  #   @square_brackets_regex
  #   |> Regex.scan(string, capture: :all_but_first)
  #   |> List.flatten()
  #   |> Enum.map(fn
  #     "[" <> term ->
  #       {value, []} = Code.eval_string(term)
  #       value

  #     string ->
  #       string
  #   end)
  #   |> dbg
  # end
end

# end
