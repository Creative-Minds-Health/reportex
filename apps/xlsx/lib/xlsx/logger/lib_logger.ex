defmodule Xlsx.Logger.LibLogger do
  require Logger

  alias :mnesia, as: Mnesia
  alias Xlsx.Logger.Logger, as: XLogger


  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxLogger, [attributes: [:node, :module, :event, :socket_id, :data, :timestamp], type: :bag])
    :ok
  end

  def save_event(module, event, socket_id, data) do
    node = case Application.get_env(:xlsx, :node) do
      :slave -> Application.get_env(:xlsx, :master)
      _-> Node.self
    end
    GenServer.cast({XLogger, node}, {:save, Node.self, module, event, socket_id, data})
  end

end
