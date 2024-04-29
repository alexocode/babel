defmodule Babel.Utils do
  @moduledoc false

  def resultify(:error), do: {:error, :unknown}
  def resultify({:error, reason}), do: {:error, reason}
  def resultify({:ok, value}), do: {:ok, value}
  def resultify(value), do: {:ok, value}
end
