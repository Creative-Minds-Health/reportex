defmodule Xlsx.XlsxMnesia do
  require Logger
  alias :mnesia, as: Mnesia

  def init() do
    :stopped = :mnesia.stop()
    :ok = :mnesia.delete_schema([node()])
    :mnesia.create_schema([node()])
    :ok = :mnesia.start()
    {:atomic, :ok} = Mnesia.create_table(XlsxWorker, [attributes: [:pid, :status, :date]])
    :ok
  end

  def dirty_write(pid, status, date)do
    :mnesia.dirty_write({XlsxWorker, pid, status, date})
  end

  def next_worker() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, :_, :waiting, :_}) end) do
      {:atomic, []} -> []
      {:atomic, [{XlsxWorker, pid, _status, _date}|_t]} -> {:ok, pid}
    end
  end

  def update_status(pid, {status, new_status}) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, pid, status, :_}) end) do
      {:atomic, []} -> :ok
      {:atomic, [{XlsxWorker, pid, _status, date}|_t]} ->
        :mnesia.dirty_write({XlsxWorker, pid, new_status, date})
    end
  end

  def delete(pid) do
    :mnesia.transaction(fn -> :mnesia.delete({XlsxWorker, pid}) end)
  end

  def empty_workers() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, :_, :_, :_}) end) do
      {:atomic, []} -> :true
      _ -> :false
    end
  end

end
