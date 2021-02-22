defmodule Xlsx.Logger.Logger do
  require Logger

  alias :mnesia, as: Mnesia

  #{
  #  "node" =>
  #  "module" =>
  #  "event" =>
  #  "data"
  #}
  # event => :master_up
  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxLogger, [attributes: [:node, :module, :event, :data, :timestamp]])
    :ok
  end

  def save_event(node, module, event, data) do
    {:ok, date} = DateTime.now("America/Mexico_City")
    :mnesia.dirty_write({XlsxLogger, node, module, event, data, DateTime.to_unix(date)})
  end
end
