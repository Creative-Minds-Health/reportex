defmodule Xlsx.Cluster.Master do
  use GenServer
  require Logger

  alias Xlsx.Cluster.Slave, as: Slave
  alias Xlsx.Mnesia.Node, as: MNode

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "Master #{inspect Node.self} is running..."
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
    Logger.info "#{inspect node} is connected..."
    response = GenServer.call({Slave, node}, :configure)
    datetime = DateTime.utc_now()
    MNode.save_node(node, response["size"], 0, DateTime.to_unix(datetime))
    {:noreply, state}
  end
  def handle_info({:nodedown, node}, state) do
    Logger.info "Node disonnected #{inspect node}"
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
