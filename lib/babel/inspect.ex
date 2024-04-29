defimpl Inspect, for: Babel.Pipeline do
  import Inspect.Algebra

  def inspect(%Babel.Pipeline{} = pipeline, opts) do
    name =
      if pipeline.name do
        concat([
          Inspect.inspect(pipeline.name, opts),
          line(),
          "|> "
        ])
      else
        empty()
      end

    concat(
      [
        name,
        "Babel.begin()"
      ] ++ steps(pipeline, opts) ++ on_error(pipeline, opts)
    )
  end

  defp steps(%Babel.Pipeline{reversed_steps: reversed_steps}, opts) do
    Enum.reduce(reversed_steps, [], fn
      %Babel.Step{} = step, list ->
        inspected_step = Inspect.inspect(step, opts)

        pipeline_step =
          if Babel.Core.core?(step) do
            inspected_step
          else
            concat(["chain(", inspected_step, ")"])
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
      [line(), "|> Babel.on_error(", Inspect.Function.inspect(on_error, opts), ")"]
    else
      []
    end
  end
end

defimpl Inspect, for: Babel.Step do
  import Inspect.Algebra

  def inspect(%Babel.Step{} = step, opts) do
    concat(["Babel.", call(step, opts)])
  end

  defp call(%Babel.Step{} = step, opts) do
    if Babel.Core.core?(step) do
      {action, args} = step.name

      concat(to_string(action), arguments(args, opts))
    else
      concat([
        "Step.new(",
        break(""),
        Inspect.inspect(step.name, opts),
        ",",
        break(),
        Inspect.inspect(step.function, opts),
        break(""),
        ")"
      ])
    end
  end

  defp arguments(args, opts) do
    container_doc("(", List.wrap(args), ")", opts, &Inspect.inspect(&1, &2))
  end
end
