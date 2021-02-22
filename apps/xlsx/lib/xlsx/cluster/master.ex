defmodule Xlsx.Cluster.Master do
  use GenServer
  require Logger

  alias Xlsx.Cluster.Slave, as: Slave
  alias Xlsx.Mnesia.Node, as: MNode
  alias Xlsx.Logger.Logger, as: XLogger

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    XLogger.save_event(Node.self(), __MODULE__, :masterup, %{})
    :ok=:net_kernel.monitor_nodes(true)
    {:ok, state}
  end

  @impl true
  def handle_call(:register, from, state) do
    Logger.info "Register"
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
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    XLogger.save_event(Node.self(), __MODULE__, :nodeup, %{"node" => node})
    response = GenServer.call({Slave, node}, :configure)
    MNode.save_node(node, response["size"], 0, DateTime.now!("America/Mexico_City") |> DateTime.to_unix())
    {:noreply, state}
  end
  def handle_info({:nodedown, node}, state) do
    XLogger.save_event(Node.self(), __MODULE__, :nodedown, %{"node" => node})
    {:noreply, state}
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
