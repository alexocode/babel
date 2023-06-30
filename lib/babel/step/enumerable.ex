defimpl Enumerable, for: Babel.Step do
  alias Babel.Step
  def count(%Step{depth: depth}), do: {:ok, depth}

  def member?(_step, _element), do: {:error, __MODULE__}

  def reduce(_step, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  def reduce(step, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(step, &1, fun)}
  end

  def reduce(%Step{} = step, {:cont, acc}, fun) do
    reduce(step.next, fun.(step, acc), fun)
  end

  def reduce(nil, {:cont, acc}, _fun), do: {:done, acc}

  def slice(_step), do: {:error, __MODULE__}
end
