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
    {:ok, Map.put(state, "workers", %{}) |> Map.put("collector", %{}) |> Map.put("total", 0) |> Map.put("page", 0)}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
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

  def handle_info({:tcp, socket, data}, %{"socket" => sock}=state) do
    data_decode = Poison.decode!(data)
    [record|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data_decode["report_key"]}) |> Enum.to_list()
    :ok=:inet.setopts(sock,[{:active, :once}])
    workers = %{}
    [%{"$match" => query} | _] = data_decode["query"];
    {:ok, total} = Mongo.count(:mongo, "egresses", query)
    {:ok, collector} = Xlsx.SrsWeb.Collector.start(%{"parent" => self(), "rows" => []})
    workers = for index <- 1..record["config"]["workers"],
      {:ok, pid} = Xlsx.SrsWeb.Worker.start(%{"parent" => self(), "rows" => record["rows"], "documents" => record["config"]["documents"], "query" => data_decode["query"], "collector" => collector}),
      {:ok, date} = DateTime.now("America/Mexico_City"),
      Process.monitor(pid),
      into: %{},
      do: {pid, %{"date" => date, "status" => :waiting}}
    send(self(), :run)
    {:noreply, Map.put(state, "workers", workers) |> Map.put("total", total)}
  end

  def handle_info(:run, %{"workers" => workers, "page" => page}=state) do
     Logger.info "AJKLAJKLAJKLAJKL"
    # case pre_run(Map.keys(workers), workers) do
    #   {:ok, pid} -> Logger.info "se encontro pid"
    #   _ -> []
    # end
    # Process.sleep(5000)
    # for pid <- Map.keys(workers),
    #   GenServer.cast(pid, :start),
    #   do: ""
    {:noreply, state}
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

  defp pre_run([], _workers) do [] end
  defp pre_run([h|t], workers) do
    case Map.get(workers, h, %{}) |> Map.get("status", :undefined) do
      :undefined -> []
      :waiting -> {:ok, h}
        _-> pre_run(t , workers)
    end
  end

end
