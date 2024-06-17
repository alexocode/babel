# coveralls-ignore-start
defmodule Babel.Inspect do
  @moduledoc false

  @doc false
  def no_breaks(doc) do
    case doc do
      {:doc_break, "", _mode} ->
        :doc_nil

      {:doc_break, break, _mode} ->
        break

      {:doc_cons, left_doc, right_doc} ->
        {:doc_cons, no_breaks(left_doc), no_breaks(right_doc)}

      {:doc_nest, doc, indent, always_or_break} ->
        {:doc_nest, no_breaks(doc), indent, always_or_break}

      {type, doc, mode} when type in [:doc_group, :doc_fits] ->
        {type, no_breaks(doc), mode}

      {:doc_fits, doc} ->
        {:doc_fits, no_breaks(doc)}

      {:doc_color, doc, color} ->
        {:doc_color, no_breaks(doc), color}

      other_doc ->
        other_doc
    end
  end
end

# coveralls-ignore-stop

defimpl Inspect, for: Babel.Pipeline do
  import Inspect.Algebra

  alias Babel.Builtin

  def inspect(%Babel.Pipeline{} = pipeline, opts) do
    name =
      if pipeline.name do
        concat([
          to_doc(pipeline.name, opts),
          break(),
          color("|> ", :operator, opts)
        ])
      else
        empty()
      end

    concat(
      [
        name,
        color(concat([color("Babel", :atom, opts), ".begin()"]), :call, opts)
      ] ++ steps(pipeline, opts) ++ on_error(pipeline, opts)
    )
  end

  defp steps(%Babel.Pipeline{reversed_steps: reversed_steps}, opts) do
    Enum.reduce(reversed_steps, [], fn
      %Babel.Pipeline{} = pipeline, list ->
        [
          concat([
            break(),
            color("|> ", :operator, opts),
            color(
              concat([
                color("Babel", :atom, opts),
                ".chain(",
                nest(concat(break(""), Inspect.Babel.Pipeline.inspect(pipeline, opts)), 2),
                break(""),
                ")"
              ]),
              :call,
              opts
            )
          ])
          | list
        ]

      applicable, list ->
        inspected_step = to_doc(applicable, opts)

        pipeline_step =
          if chainable?(applicable) do
            inspected_step
          else
            color(
              concat([color("Babel", :atom, opts), ".chain(", inspected_step, ")"]),
              :call,
              opts
            )
          end

        [concat([break(), color("|> ", :operator, opts), pipeline_step]) | list]
    end)
  end

  @chainable ~w[
    call
    cast
    choice
    const
    fetch
    flat_map
    get
    into
    map
    then
    try
  ]a
  defp chainable?(babel) do
    Builtin.builtin?(babel) and Builtin.name_of_builtin!(babel) in @chainable
  end

  defp on_error(%Babel.Pipeline{on_error: on_error}, opts) do
    if on_error do
      [
        break(),
        color("|> ", :operator, opts),
        Inspect.Babel.Pipeline.OnError.inspect(on_error, opts)
      ]
    else
      []
    end
  end
end

defimpl Inspect, for: Babel.Pipeline.OnError do
  import Inspect.Algebra

  def inspect(%Babel.Pipeline.OnError{handler: handler}, opts) do
    color(
      concat([
        color("Babel", :atom, opts),
        ".on_error(",
        Inspect.Function.inspect(handler, opts),
        ")"
      ]),
      :call,
      opts
    )
  end
end

defimpl Inspect, for: Babel.Trace do
  import Babel.Inspect
  import Inspect.Algebra

  def inspect(%Babel.Trace{} = trace, opts) do
    level = Keyword.get(opts.custom_options, :indent, 0)

    nest(
      concat([
        nesting(level),
        trace(trace, opts),
        color("{", :operator, opts),
        nest(properties(trace, opts), 2),
        line(),
        color("}", :operator, opts)
      ]),
      level
    )
  end

  defp nesting(level, indent \\ [])
  defp nesting(0, indent), do: concat(indent)
  defp nesting(level, indent) when level > 0, do: nesting(level - 1, [" " | indent])

  defp trace(trace, opts) do
    {status, color} =
      if Babel.Trace.ok?(trace) do
        {"OK", :green}
      else
        {"ERROR", :red}
      end

    group(
      concat([
        color("Babel.Trace", :atom, opts),
        color("<", :operator, opts),
        force_color(status, color, opts),
        color(">", :operator, opts)
      ])
    )
  end

  # No colors means the output doesn't support colors
  defp force_color(doc, _color, %{syntax_colors: []}), do: doc

  # Manually tested in iex
  # coveralls-ignore-start
  defp force_color(doc, color, %{syntax_colors: syntax_colors}) do
    postcolor = Keyword.get(syntax_colors, :reset, :reset)

    concat([{:doc_color, doc, color}, {:doc_color, :doc_nil, postcolor}])
  end

  # coveralls-ignore-stop

  defp properties(trace, opts) do
    concat([
      line(),
      data(trace, opts),
      line(),
      line(),
      babel(trace, opts),
      line(),
      nested(trace, opts),
      output(trace, opts)
    ])
  end

  defp data(%{input: data}, opts) do
    group(
      nest(
        flex_glue(
          concat([color("data", :variable, opts), " ", color("=", :operator, opts)]),
          to_doc(data, opts)
        ),
        2
      )
    )
  end

  defp babel(%Babel.Trace{babel: babel}, opts), do: babel(babel, opts)

  defp babel(%Babel.Pipeline{name: name}, opts) do
    name_doc =
      if is_nil(name) do
        empty()
      else
        to_doc(name, opts)
      end

    group(concat([color("Babel.Pipeline", :atom, opts), "<", name_doc, ">"]))
  end

  defp babel(%Babel.Pipeline.OnError{} = on_error, opts) do
    Inspect.Babel.Pipeline.OnError.inspect(on_error, opts)
  end

  defp babel(applicable, opts) do
    to_doc(applicable, opts)
  end

  defp nested(%{nested: []}, _opts), do: empty()

  defp nested(%{nested: nested}, opts) do
    nested
    |> lines_for_nested(opts)
    |> Enum.flat_map(&[&1, line()])
    |> concat()
    |> group()
  end

  defp lines_for_nested([], _opts), do: []

  defp lines_for_nested(traces, opts) when is_list(traces) do
    only_error = Keyword.get(opts.custom_options, :only_error, false)

    {traces, nr_of_omitted} =
      if only_error do
        nested_errors = Enum.filter(traces, &Babel.Trace.error?/1)

        {
          nested_errors,
          length(traces) - length(nested_errors)
        }
      else
        {traces, 0}
      end

    traces
    |> Enum.map(fn trace ->
      [
        no_breaks(babel(trace.babel, opts)),
        input(trace, opts),
        lines_for_nested(trace.nested, opts),
        output(trace, opts),
        ""
      ]
    end)
    |> List.flatten()
    |> List.insert_at(0, "")
    |> summarize_omissions(nr_of_omitted)
    |> Enum.map(&concat("| ", &1))
  end

  defp input(%{input: input}, opts), do: input(input, opts)

  defp input(input, opts) do
    no_breaks(concat(["|=< ", to_doc(input, %{opts | limit: 5})]))
  end

  defp output(%Babel.Trace{} = trace, opts) do
    trace
    |> Babel.Trace.result()
    |> output(opts)
  end

  defp output(output, opts) do
    value =
      case output do
        {:ok, value} -> value
        {:error, reason} -> {:error, reason}
      end

    no_breaks(concat("|=> ", to_doc(value, %{opts | limit: 5})))
  end

  defp summarize_omissions(lines, 0), do: lines
  defp summarize_omissions(lines, n), do: ["", "... OK traces omitted (#{n}) ..." | lines]
end
