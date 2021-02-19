defmodule Xlsx.Mnesia.Node do
  require Logger
  alias :mnesia, as: Mnesia

  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxNode, [attributes: [:node, :size, :doing]])
    :ok
  end

  def save_node(node, size, doing) do
    :mnesia.dirty_write({XlsxNode, node, size, doing})
  end
end
