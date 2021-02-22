defmodule Xlsx.Mnesia.Node do
  require Logger
  alias :mnesia, as: Mnesia

  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxNode, [attributes: [:node, :size, :doing, :last_report_date]])
    :ok
  end

  def save_node(node, size, doing, last_report_date) do
    :mnesia.dirty_write({XlsxNode, node, size, doing, last_report_date})
  end

  def get_next_node() do
    case :mnesia.transaction(fn -> :mnesia.select(XlsxNode, [{{XlsxNode, :"$1", :"$2", :"$3", :"$4"}, [], [:"$$"]}]) end) do
      {:atomic, []} -> :undefined
      {:atomic, list} ->
        format_list = format_list(list, [])
        get_next_node(Enum.sort_by(format_list, &(&1["last_report_date"])), %{})
    end
  end

  def format_list([], list) do
    list
  end

  def format_list([[node, size, doing, last_report_date] | t], list) do
    format_list(t, list ++ [Map.put(%{}, "node", node) |> Map.put("size", size) |> Map.put("doing", doing) |> Map.put("last_report_date", last_report_date)])
  end

  def get_next_node([], %{}) do
    :undefined
  end

  def get_next_node([], node) do
    node
  end

  def get_next_node([h | t], node) do
    case h["doing"] < h["size"] do
      true ->
        get_next_node(t, h)
      _-> get_next_node(t, node)
    end
  end
end

# :mnesia.create_table(XlsxNode, [attributes: [:node, :size, :doing, :last_report_date]])
# datetime = DateTime.utc_now()
# :mnesia.dirty_write({XlsxNode, :"enrique@192.168.0.8", 5, 0, DateTime.to_unix(datetime)})
# :mnesia.dirty_write({XlsxNode, :"leticia@192.168.0.4", 5, 0, DateTime.to_unix(datetime)})

# :mnesia.transaction(fn -> :mnesia.match_object({XlsxNode, :_, :_, :_, :_}) end)
