defmodule Xlsx.Report.Report do
  require Logger

  # API
  def col_widths(columns) do
    col_widths(1, columns, %{})
  end
  def col_widths(start, columns) do
    col_widths(start, columns, %{})
  end

  defp col_widths(index, [], acc), do: Map.put(acc, index, 30)
  defp col_widths(index, [h|t], acc) do
    width = get_width(h)
    col_widths(index + 1, t, Map.put(acc, index, width))
  end

  defp get_width([]) do
    30
  end
  defp get_width([{:width, width} | t]) do
    width
  end
  defp get_width([_ | t]) do
    get_width(t)
  end

end
