defmodule Xlsx.Mnesia.Worker do
  require Logger
  alias :mnesia, as: Mnesia

  def init() do
    {:atomic, :ok} = Mnesia.create_table(XlsxWorker, [attributes: [:pid, :status, :date, :report]])
    :ok
  end

  def dirty_write(pid, status, date, report)do
    :mnesia.dirty_write({XlsxWorker, pid, status, date, report})
  end

  def next_worker() do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, :_, :waiting, :_, :_}) end) do
      {:atomic, []} -> []
      {:atomic, [{XlsxWorker, pid, _status, _date, _report}|_t]} -> {:ok, pid}
    end
  end

  def update_status(pid, {status, new_status}) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, pid, status, :_, :_}) end) do
      {:atomic, []} -> :ok
      {:atomic, [{XlsxWorker, pid, _status, date, report}|_t]} ->
        :mnesia.dirty_write({XlsxWorker, pid, new_status, date, report})
    end
  end

  def delete(pid) do
    {:atomic, :ok} = :mnesia.transaction(fn ->
      :mnesia.dirty_delete({XlsxWorker, pid})
    end)
  end

  def empty_workers(report) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, :_, :_, :_, report}) end) do
      {:atomic, []} -> :true
      _ -> :false
    end
  end

  def get_workers(report) do
    case :mnesia.transaction(fn -> :mnesia.match_object({XlsxWorker, :_, :_, :_, report}) end) do
      {:atomic, []} -> []
      {:atomic, list} -> list
    end
  end
end
