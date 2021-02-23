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
    {:atomic, :ok} = Mnesia.create_table(XlsxLogger, [attributes: [:node, :module, :event, :socket_id, :data, :timestamp], type: :bag])
    :ok
  end

  def save_event(node, module, event, socket_id, data) do
    {:ok, date} = DateTime.now("America/Mexico_City")
    info = case event do
      :report_start -> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id}"]
      :count -> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id} - total: #{inspect data["total"]}"]
      _-> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id} -#{inspect data}"]
    end
    Logger.info info
    :mnesia.dirty_write({XlsxLogger, node, module, event, socket_id, data, DateTime.to_unix(date)})
  end

end
