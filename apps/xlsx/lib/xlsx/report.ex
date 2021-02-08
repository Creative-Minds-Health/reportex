defmodule Xlsx.Report do
  use GenServer
  require Logger

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "Reportex GenServer is running..."
    GenServer.cast(self(), :listener)
    {:ok, Map.put(state, "collector", %{}) |> Map.put("total", 0) |> Map.put("page", 1) |> Map.put("skip", 0)}
  end

  @impl true
  def handle_call(:waiting_status, {from, _}, state) do
    :ok = Xlsx.XlsxMnesia.update_status(from, {:occupied, :waiting})
    {:reply, :ok, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:listener, %{"lsocket" => lsocket, "parent" => parent}=state) do
    {:ok, socket} = :gen_tcp.accept(lsocket)
    Logger.info ["Pid #{inspect __MODULE__} socket accepted"]
    GenServer.cast(parent, :create_child)
    :ok = :inet.setopts(socket,[{:active,:once}])
    {:noreply, Map.put(state, "socket", socket), 300_000};
  end
  def handle_cast(:stop, %{"socket" => socket}=state) do
    :ok=:gen_tcp.close(socket)
    Logger.warning ["#{inspect self()},#{inspect socket}... tcp_closed"]
    {:stop, :normal, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _reason}, state) do
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end

  def handle_info({:tcp, _socket, data}, %{"socket" => sock, "page" => page}=state) do
    data_decode = Poison.decode!(data)
    [record|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data_decode["report_key"]}) |> Enum.to_list()
    :ok=:inet.setopts(sock,[{:active, :once}])
    [%{"$match" => query} | _] = data_decode["query"];
    {:ok, total} = Mongo.count(:mongo, record["collection"], query)
    names = for item <- record["rows"],
      into: [],
      do: [item["name"], bold: true, font: "Arial", size: 12]
       Logger.warning ["names #{inspect names}"]
    {:ok, collector} = Xlsx.SrsWeb.Collector.start(%{"parent" => self(), "rows" => [], "columns" => names})
    n_workers = get_n_workers(total, round(total / record["config"] ["documents"]), record["config"]["workers"])
    for _index <- 1..n_workers,
      {:ok, pid} = Xlsx.SrsWeb.Worker.start(%{"parent" => self(), "rows" => record["rows"], "query" => data_decode["query"], "collector" => collector, "collection" => record["collection"]}),
      {:ok, date} = DateTime.now("America/Mexico_City"),
      Process.monitor(pid),
      :ok = Xlsx.XlsxMnesia.dirty_write(pid, :waiting, date),
      into: %{},
      do: {pid, %{"date" => date, "status" => :waiting}}
    send(self(), {:run, page * record["config"]["documents"]})
    {:noreply, Map.put(state, "total", total) |> Map.put("documents", record["config"]["documents"]) |> Map.put("collector", collector)}
  end

  def handle_info({:run_by_worker, from}, %{"total" => total, "skip" => skip}=state) when skip >= total do
    GenServer.cast(from, :stop)
    {:noreply, state}
  end
  def handle_info({:run_by_worker, _from}, %{"page" => page, "documents" => documents, "total" => total, "skip" => skip}=state) do
    Logger.info ["total #{inspect total}, skip #{inspect skip}"]
    send(self(), {:run, page * documents})
    {:noreply, state}
  end

  def handle_info({:run, _limit}, %{"total" => total, "skip" => skip}=state) when skip >= total do
    Logger.warning "Se mandaron todos los registros"
    {:noreply, state}
  end

  def handle_info({:run, limit}, %{"total" => total, "skip" => skip, "documents" => documents, "page" => page}=state) when limit <= total do
    new_state = case Xlsx.XlsxMnesia.next_worker() do
      {:ok, pid} ->
        send(pid, {:run, skip, limit, documents})
        send(self(), {:run, (page + 1) * documents})
        :ok = Xlsx.XlsxMnesia.update_status(pid, {:waiting, :occupied})
        Map.put(state, "skip", limit) |> Map.put("page", page + 1)
      _ ->
        state
    end
    {:noreply, new_state}
  end
  def handle_info({:run, limit}, %{"page" => page, "total" => total, "skip" => skip, "documents" => _documents}=state)  when limit > total do
    new_state = case Xlsx.XlsxMnesia.next_worker() do
      {:ok, pid} ->
        # Logger.warning ["page #{page}, skip #{inspect skip}, limit #{inspect limit}, documents #{inspect documents}"]
        send(pid, {:run, skip, total, (total - skip)})
        send(self(), {:run, total})
        :ok = Xlsx.XlsxMnesia.update_status(pid, {:waiting, :occupied})
        Map.put(state, "skip", limit) |> Map.put("page", page + 1)
      _ ->
        state
    end
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{"collector" => collector}=state) do
    Logger.warning ["#{inspect pid} worker... deleted"]
    {:atomic, :ok} = Xlsx.XlsxMnesia.delete(pid)
    case Xlsx.XlsxMnesia.empty_workers() do
      :true ->
        GenServer.cast(collector, :generate)
      _ -> []
    end
    {:noreply, state}
  end
  # def handle_info({:tcp, socket, data}, %{socket: sock}=state) do
  #   Logger.info ["Socket message #{inspect data}"]
  #   :ok=:inet.setopts(sock,[{:active, :once}])
  #   {:noreply, Map.put(state, :response_socket, socket), 300_000}
  # end
  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{inspect msg}"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warning ["#{inspect self()}... terminate"]
    :ok
  end

  def get_n_workers(0, round_total, config_workers) do
    Logger.info ["Error en total"]
  end
  def get_n_workers(total, 0, config_workers) do
    get_n_workers(total, 1, config_workers)
  end
  def get_n_workers(total, round_total, config_workers) do
    case round_total < config_workers do
      :true -> round_total
      :false ->  config_workers
    end
  end

end
