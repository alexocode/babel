defimpl Inspect, for: Babel.Pipeline do
  import Inspect.Algebra

  def inspect(%Babel.Pipeline{} = pipeline, opts) do
    name =
      if pipeline.name do
        concat([
          to_doc(pipeline.name, opts),
          line(),
          "|> "
        ])
      else
        empty()
      end

    concat(
      [
        name,
        color("Babel.begin()", :call, opts)
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
            color(concat(["chain(", inspected_step, ")"]), :call, opts)
          end

        [concat([line(), "|> ", pipeline_step]) | list]

      %Babel.Pipeline{} = pipeline, list ->
        [
          concat([
            line(),
            "|> chain(",
            nest(concat(break(""), Inspect.Babel.Pipeline.inspect(pipeline, opts)), 1),
            break(""),
            ")"
          ])
          | list
        ]
    end)
  end

  defp on_error(%Babel.Pipeline{on_error: on_error}, opts) do
    if on_error do
      [line(), "|> ", Inspect.Babel.Pipeline.OnError.inspect(on_error, opts)]
    else
      []
    end
  end
end

defimpl Inspect, for: Babel.Pipeline.OnError do
  import Inspect.Algebra

  def inspect(%Babel.Pipeline.OnError{handler: handler}, opts) do
    color(
      concat(["Babel.on_error(", Inspect.Function.inspect(handler, opts), ")"]),
      :call,
      opts
    )
  end
end

defimpl Inspect, for: Babel.Step do
  import Inspect.Algebra

  def inspect(%Babel.Step{} = step, opts) do
    color(concat(["Babel.", call(step, opts)]), :call, opts)
  end

  defp call(%Babel.Step{} = step, opts) do
    if Babel.Core.core?(step) do
      {action, args} = step.name

      concat(to_string(action), arguments(args, opts))
    else
      color(
        concat([
          "Step.new(",
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
    concat([
      trace(trace, opts),
      nest(properties(trace, opts), 2)
    ])
  end

  defp trace(trace, opts) do
    status =
      if Babel.Trace.ok?(trace) do
        :ok
      else
        :error
      end

    group(
      concat([
        color(string("Babel.Trace"), :atom, opts),
        "<",
        to_doc(status, opts),
        ">"
      ])
    )
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
      line(),
      result(trace, opts)
    ])
  end

  defp data(%{data: data}, opts) do
    group(nest(glue("data:", to_doc(data, opts)), 2))
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
    |> Enum.intersperse(line())
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
