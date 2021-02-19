defmodule Xlsx.Register do
  use GenServer
  require Logger

  alias Xlsx.Listener, as: XListener
  alias Xlsx.Mnesia.Node, as: MNode

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "Register is running..."
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
    Logger.info "Node connected #{inspect node}"
    response = GenServer.call({XListener, node}, :configure)
    Logger.info ["Response: #{inspect response}"]
    MNode.save_node(node, response["size"], 0)
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
