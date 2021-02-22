defmodule Xlsx.Cluster.Listener do
  use GenServer
  require Logger

  alias Xlsx.Logger.Logger, as: XLogger

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, "connected", :false) |> Map.put("workers", %{}), name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    report_config = Application.get_env(:xlsx, :report)
    new_state = Map.put(state, "master", Application.get_env(:xlsx, :master)) |> Map.put("size", report_config[:size])
    case Application.get_env(:xlsx, :node) do
      :slave ->
        {:ok, new_state, 2_000}
      _ ->
        {:ok, new_state}
    end
  end

  @impl true
  def handle_call(:configure, _from, %{"size" => size}=state) do
    :ok = Xlsx.Supervisor.start_children([:nodejs, :mongodb])
    {:reply, %{"size" => size}, state}
  end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:generate_report, res_socket}, state) do
    {:ok, pid} = Xlsx.Report.start(%{"res_socket" => res_socket, "parent" => self()})
    {:ok, date} = DateTime.now("America/Mexico_City")
    Process.monitor(pid)
    {:noreply, Map.put(state, "workers", Map.put(state["workers"], pid, %{"init_date" => date}))}
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, %{"connected" => :true, "master" => master}=state) do
    {:noreply, state}
  end
  def handle_info(:timeout, %{"connected" => :false, "master" => master}=state) do
    XLogger.save_event(Node.self(), __MODULE__, :timeout, %{"master" => master})
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
