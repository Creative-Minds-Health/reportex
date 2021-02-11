defmodule Xlsx.Mnesia.Socket do
  require Logger
  alias :mnesia, as: Mnesia

  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxSocket, [attributes: [:id, :data, :turno, :date], type: :ordered_set])
    :ok
  end

  def dirty_write(id, data, turno, date)do
    :mnesia.dirty_write({XlsxSocket, id, data, turno, date})
    Logger.warning ["lista de sockets: #{inspect :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_}) end)}"]
  end

  def delete(id) do
    {:atomic, :ok} = :mnesia.transaction(fn -> :mnesia.dirty_delete({XlsxSocket, id}) end)
    Logger.warning ["lista de sockets: #{inspect :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_}) end)}"]
  end

  def next_socket() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_}) end) do
      {:atomic, []} -> []
      {:atomic, [socket|_t]} -> {:ok, socket}
    end
  end

  def empty_sockets() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_}) end) do
      {:atomic, []} -> :true
      {:atomic, list} ->
        length(list) + 1
    end
  end
end
