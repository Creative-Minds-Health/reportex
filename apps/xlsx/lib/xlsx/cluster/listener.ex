defmodule Xlsx.Cluster.Listener do
  use GenServer
  require Logger

  alias Xlsx.Logger.Logger, as: XLogger
  alias Xlsx.Mnesia.Node, as: MNode

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, "connected", :false) |> Map.put("reports", %{}), name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    report_config = Application.get_env(:xlsx, :report)
    new_state = Map.put(state, "master", Application.get_env(:xlsx, :master)) |> Map.put("size", report_config[:size])
    case Application.get_env(:xlsx, :node) do
      :slave ->
        :ok=:net_kernel.monitor_nodes(true)
        {:ok, new_state, 2_000}
      _ ->
        {:ok, new_state}
    end
  end

  @impl true
  def handle_call({:generate_report, request}, state) do
    {:ok, pid} = Xlsx.Report.Report.start(Map.put(request, "listener", self()))
    {:ok, date} = DateTime.now("America/Mexico_City")
    Process.monitor(pid)
    {:reply, pid, Map.put(state, "reports", Map.put(state["reports"], pid, %{"init_date" => date, "request" => request["request"]}))}
  end
  def handle_call(:configure, _from, %{"size" => size}=state) do
    # :ok = Xlsx.Supervisor.start_children([:nodejs, :mongodb])
    {:reply, %{"size" => size}, state}
  end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:kill, report}, state) do
    send(report, :kill)
    {:stop, :normal, state}
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{"reports" => reports}=state) do
    report = reports[pid];
    GenServer.cast(report["request"], {:stop, Node.self})
    {:noreply, state}
  end

  def handle_info({:nodeup, node}, state) do
    # XLogger.save_event(Node.self(), __MODULE__, :nodeup, %{"node" => node})
    # response = GenServer.call({Listener, node}, :configure)
    # MNode.save_node(node, response["size"], 0, DateTime.now!("America/Mexico_City") |> DateTime.to_unix())
    {:noreply, state}
  end
  def handle_info({:nodedown, node}, %{"connected" => :true, "master" => node}=state) do
    case Application.get_env(:xlsx, :node) do
      :slave ->
        Logger.error ["nodedown #{inspect node} "]
        {:noreply, Map.put(state, "connected", :false), 2_000}
      _->
        {:noreply, state}
    end
  end
  def handle_info(:timeout, %{"connected" => :true, "master" => master}=state) do
    {:noreply, state}
  end
  def handle_info(:timeout, %{"connected" => :false, "master" => master}=state) do
    Logger.error ["timeout to connect #{inspect master}"]
    {:noreply, Map.put(state, "connected", Node.connect master), 2_000}
  end
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warning ["#{inspect self()}... terminate"]
    :ok
  end
end
