defmodule Xlsx.Report do
  use GenServer
  require Logger

  alias Elixlsx.Sheet
  alias Elixlsx.Workbook

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
    {:ok, Map.put(state, "workers", %{}) |> Map.put("collector", %{}) |> Map.put("total", 0) |> Map.put("page", 1) |> Map.put("skip", 0)}
  end

  @impl true
  def handle_call(:waiting_status, {from, _}, state) do
    state = Map.put(state, "workers", Map.put(state["workers"], from, Map.put(state["workers"][from], "status", :waiting)))
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

  def handle_info({:tcp, socket, data}, %{"socket" => sock, "page" => page}=state) do
    data_decode = Poison.decode!(data)
    [record|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data_decode["report_key"]}) |> Enum.to_list()
    :ok=:inet.setopts(sock,[{:active, :once}])
    workers = %{}
    [%{"$match" => query} | _] = data_decode["query"];
    {:ok, total} = Mongo.count(:mongo, "egresses", query)
    Logger.warning ["total #{inspect total}"]
    {:ok, collector} = Xlsx.SrsWeb.Collector.start(%{"parent" => self(), "rows" => []})
    workers = for index <- 1..record["config"]["workers"],
      {:ok, pid} = Xlsx.SrsWeb.Worker.start(%{"parent" => self(), "rows" => record["rows"], "query" => data_decode["query"], "collector" => collector}),
      {:ok, date} = DateTime.now("America/Mexico_City"),
      Process.monitor(pid),
      into: %{},
      do: {pid, %{"date" => date, "status" => :waiting}}
    Logger.info ("workers created #{inspect workers}")
    send(self(), {:run, page * record["config"]["documents"]})
    {:noreply, Map.put(state, "workers", workers) |> Map.put("total", total) |> Map.put("documents", record["config"]["documents"])}
  end

  def handle_info(:run, %{"documents" => documents, "page" => page}=state) do
    send(self(), {:run, (page + 1) * documents})
    {:noreply, state}
  end

  def handle_info({:run, limit}, %{"total" => total, "skip" => skip}=state) when skip >= total do
    Logger.warning "Se mandaron todos los registros"
    {:noreply, state}
  end

  def handle_info({:run, limit}, %{"total" => total, "workers" => workers, "skip" => skip, "documents" => documents, "page" => page}=state) when limit <= total do
    new_state = case next_worker(Map.keys(workers), workers) do
      {:ok, pid} ->
        send(pid, {:run, skip, limit, documents})
        send(self(), {:run, (page + 1) * limit})

        Map.put(state, "workers", Map.put(state["workers"], pid, Map.put(state["workers"][pid], "status", :occupied))) |> Map.put("skip", limit) |> Map.put("page", page + 1)
      _ ->
        Logger.warning ["Ya no hay trabajadores"]
        state
    end
    {:noreply, new_state}
  end
  def handle_info({:run, limit}, %{"workers" => workers, "page" => page, "total" => total, "skip" => skip, "documents" => documents}=state)  when limit > total do
    new_state = case next_worker(Map.keys(workers), workers) do
      {:ok, pid} ->
        send(pid, {:run, skip, total, (total - skip)})
        send(self(), {:run, total})

        Map.put(state, "workers", Map.put(state["workers"], pid, Map.put(state["workers"][pid], "status", :occupied))) |> Map.put("skip", limit) |> Map.put("page", page + 1)
      _ ->
        Logger.warning ["Ya no hay trabajadores"]
        state
    end
    # case next_worker()
    # case next_worker(Map.keys(workers), workers) do
    #   {:ok, pid} -> Logger.info "Poner a trabajar #{inspect pid}"
    #   _ -> []
    # end
    # Process.sleep(5000)
    # for pid <- Map.keys(workers),
    #   GenServer.cast(pid, :start),
    #   do: ""
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.warning ["#{inspect pid} worker... deleted"]
    {:noreply, Map.put(state, "workers", Map.delete(state["workers"], pid))}
  end
  # def handle_info({:tcp, socket, data}, %{socket: sock}=state) do
  #   Logger.info ["Socket message #{inspect data}"]
  #   :ok=:inet.setopts(sock,[{:active, :once}])
  #   {:noreply, Map.put(state, :response_socket, socket), 300_000}
  # end
  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{msg}"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warning ["#{inspect self()}... terminate"]
    :ok
  end

  defp next_worker([], _workers) do [] end
  defp next_worker([h|t], workers) do
    case Map.get(workers, h, %{}) |> Map.get("status", :undefined) do
      :undefined -> []
      :waiting -> {:ok, h}
        _-> next_worker(t , workers)
    end
  end

  defp set_status_worker(workers,pid) do
    case Map.get(workers, pid, :undefined) do
      pid ->
        Logger.warning ["#{inspect Map.get(workers, pid, :undefined)}"]
      _-> []
    end
  end

end
