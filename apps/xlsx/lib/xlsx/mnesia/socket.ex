defmodule Xlsx.Mnesia.Socket do
  require Logger
  alias :mnesia, as: Mnesia

  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxSocket, [attributes: [:id, :report, :data, :turno, :date, :status], type: :ordered_set])
    :ok
  end


  def save_socket(socket, report, data, turn, status) do
    {:ok, date} = DateTime.now("America/Mexico_City")
    :mnesia.dirty_write({XlsxSocket, socket, report, data, turn, date, status})
    data
  end

  def delete(id) do
    {:atomic, :ok} = :mnesia.transaction(fn -> :mnesia.dirty_delete({XlsxSocket, id}) end)
    # Logger.warning ["lista de sockets: #{inspect :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_, :_, :_}) end)}"]
  end

  def update_status(id, {status, new_status}) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, id, :_, :_, :_, :_, status}) end) do
      {:atomic, []} -> :ok
      {:atomic, [{XlsxSocket, id, report, data, turno, date, _status}|_t]} ->
        :mnesia.dirty_write({XlsxSocket, id, report, data, turno, date, new_status})
    end
  end

  def check_kill_pid(report) do
    :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, report, :_, :_, :_, :_}) end)
  end

  def next_socket() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_, :_, :waiting}) end) do
      {:atomic, []} -> []
      {:atomic, [socket|_t]} -> {:ok, socket}
    end
  end

  def empty_sockets() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_, :_, :_}) end) do
      {:atomic, []} -> 1
      {:atomic, list} ->
        length(list) + 1
    end
  end

  def waiting_sockets() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxSocket, :_, :_, :_, :_, :_, :waiting}) end) do
      {:atomic, []} -> []
      {:atomic, list} -> list
    end
  end
end
