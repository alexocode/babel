defimpl Inspect, for: Babel.Pipeline do
  import Inspect.Algebra

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
      %Babel.Step{} = step, list ->
        inspected_step = to_doc(step, opts)

        pipeline_step =
          if Babel.Core.core?(step) do
            inspected_step
          else
            color(
              concat([color("Babel", :atom, opts), "chain(", inspected_step, ")"]),
              :call,
              opts
            )
          end

        [concat([break(), color("|> ", :operator, opts), pipeline_step]) | list]

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
    end)
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

defimpl Inspect, for: Babel.Step do
  import Inspect.Algebra

  def inspect(%Babel.Step{} = step, opts) do
    color(concat([color("Babel", :atom, opts), ".", call(step, opts)]), :call, opts)
  end

  defp call(%Babel.Step{} = step, opts) do
    if Babel.Core.core?(step) do
      {action, args} = step.name

      concat(to_string(action), arguments(args, opts))
    else
      color(
        concat([
          color("Step", :atom, opts),
          ".new(",
          break(""),
          to_doc(step.name, opts),
          ",",
          break(),
          to_doc(step.function, opts),
          break(""),
          ")"
        ]),
        :call,
        opts
      )
    end
  end

  defp arguments(args, opts) do
    container_doc("(", List.wrap(args), ")", opts, &to_doc(&1, &2))
  end
end

defimpl Inspect, for: Babel.Trace do
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

  defp force_color(doc, color, _opts) do
    concat([{:doc_color, doc, color}, {:doc_color, :doc_nil, :reset}])
  end

  defp properties(trace, opts) do
    concat([
      line(),
      data(trace, opts),
      line(),
      line(),
      babel(trace, opts),
      line(),
      nested(trace, opts),
      result(trace, opts)
    ])
  end

  defp data(%{data: data}, opts) do
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

  defp babel(%Babel.Step{} = step, opts) do
    Inspect.Babel.Step.inspect(step, opts)
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
    [
      "",
      for trace <- traces do
        [
          no_limit(babel(trace.babel, opts)),
          lines_for_nested(trace.nested, opts),
          result(trace, opts),
          ""
        ]
      end
    ]
    |> List.flatten()
    |> Enum.map(&concat("| ", &1))
  end

  defp result(trace, opts) do
    group(concat("|=> ", raw_result(trace, opts)))
  end

  defp raw_result(%{result: result}, opts) do
    result
    |> case do
      {:ok, value} -> value
      {:error, reason} -> {:error, reason}
    end
    |> to_doc(opts)
  end
end
