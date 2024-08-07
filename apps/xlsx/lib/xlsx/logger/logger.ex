defmodule Xlsx.Logger.Logger do
  use GenServer
  require Logger


  # event => :nodeup, :nodedown, :tcp_accepted, :tcp_message, :report_start, :count, :run_all, :generating_xlsx, :done_xlsx, :upload_xlsx, :kill_progress, kill_collector, :kill_report

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @impl true
  def handle_call({:send_progress, res_socket, response}, _from, state) do
    :gen_tcp.send(res_socket, response)
    {:reply, :ok, state}
  end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast({:save, node, module, :error, socket_id, data}, state) do
    {:ok, date} = DateTime.now("America/Mexico_City")
    Logger.error ["#{inspect node} - #{inspect module} - #{inspect :error} - #{inspect socket_id} -#{inspect data}"]
    :mnesia.dirty_write({XlsxLogger, node, module, :error, socket_id, data, DateTime.to_unix(date)})
    {:noreply, state}
  end
  def handle_cast({:save, node, module, event, socket_id, data}, state) do
    {:ok, date} = DateTime.now("America/Mexico_City")
    case event do
      :report_start -> Logger.info ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id}"]
      :generating_xlsx -> Logger.info ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id}"]
      :done_xlsx -> Logger.info ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id}"]
      :nodeup -> Logger.info ["#{inspect node} - #{inspect module} - #{inspect event}"]
      :nodedown -> Logger.info ["#{inspect node} - #{inspect module} - #{inspect event}"]
      #:run_all, :count, :tcp_message, :tcp_accepted -> []
      _-> []
    end
    :mnesia.dirty_write({XlsxLogger, node, module, event, socket_id, data, DateTime.to_unix(date)})
    {:noreply, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warning ["#{inspect self()}... terminate"]
    :ok
  end

  def all() do
    {:atomic, data} = :mnesia.transaction(fn -> :mnesia.match_object({XlsxLogger, :_, :_, :_, :_, :_, :_}) end)
    show_all(data)
  end

  defp show_all([]) do
  end
  defp show_all([{_table, node, module, event, socket_id, data, _date}|t]) do
    info = case event do
      :report_start -> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id}"]
      :run_all -> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id}"]
      :count -> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id} - total: #{inspect data["total"]}"]
      _-> ["#{inspect node} - #{inspect module} - #{inspect event} - #{inspect socket_id} -#{inspect data}"]
    end
    Logger.info info
    show_all(t)
  end
end
