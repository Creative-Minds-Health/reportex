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

  def increment_doing(:undefined) do
    :undefined
  end

  def increment_doing(node) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxNode, node["node"], :_, :_, :_}) end) do
      {:atomic, []} -> :ok
      {:atomic, [{XlsxNode, _id, size, doing, _last_report_date}|_t]} ->
        :mnesia.dirty_write({XlsxNode, node["node"], size, doing + 1, DateTime.now!("America/Mexico_City") |> DateTime.to_unix()})
        node
    end
  end

  def decrement_doing(node) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxNode, node, :_, :_, :_}) end) do
      {:atomic, []} -> :ok
      {:atomic, [{XlsxNode, _id, size, doing, last_report_date}|_t]} ->
        :mnesia.dirty_write({XlsxNode, node, size, doing - 1, last_report_date})
    end
  end

  def next_node() do
    case :mnesia.transaction(fn -> :mnesia.select(XlsxNode, [{{XlsxNode, :"$1", :"$2", :"$3", :"$4"}, [], [:"$$"]}]) end) do
      {:atomic, []} -> :undefined
      {:atomic, list} ->
        format_list(list, [])
          |> Enum.sort_by(&(&1["last_report_date"]))
          |> next_node(%{})
          |> increment_doing()
    end
  end

  def format_list([], list) do
    list
  end

  def format_list([[node, size, doing, last_report_date] | t], list) do
    format_list(t, list ++ [Map.put(%{}, "node", node) |> Map.put("size", size) |> Map.put("doing", doing) |> Map.put("last_report_date", last_report_date)])
  end

  def next_node([], %{}) do
    :undefined
  end

  def next_node([], node) do
    node
  end

  def next_node([h|t], node) do
    case h["doing"] < h["size"] do
      true -> h
      _-> next_node(t, node)
    end
  end
end

# :mnesia.create_table(XlsxNode, [attributes: [:node, :size, :doing, :last_report_date]])
# datetime = DateTime.utc_now()
# :mnesia.dirty_write({XlsxNode, :"enrique@192.168.0.8", 5, 0, DateTime.to_unix(datetime)})
# :mnesia.dirty_write({XlsxNode, :"leticia@192.168.0.4", 5, 0, DateTime.to_unix(datetime)})

# :mnesia.transaction(fn -> :mnesia.match_object({XlsxNode, :_, :_, :_, :_}) end)
