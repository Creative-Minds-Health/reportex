defmodule Xlsx.Cluster.Master do
  use GenServer
  require Logger

  alias Xlsx.Cluster.Listener, as: Listener
  alias Xlsx.Mnesia.Node, as: MNode
  alias Xlsx.Logger.LibLogger, as: LibLogger

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    LibLogger.save_event(__MODULE__, :masterup, :nill, %{})
    :ok=:net_kernel.monitor_nodes(true)
    {:ok, state}
  end

  @impl true
  def handle_call(:register, _from, state) do
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
    LibLogger.save_event(__MODULE__, :nodeup, :nill, %{"node" => node})
    response = GenServer.call({Listener, node}, :configure)
    MNode.save_node(node, response["size"], 0, DateTime.now!("America/Mexico_City") |> DateTime.to_unix())
    {:noreply, state}
  end
  def handle_info({:nodedown, node}, state) do
    LibLogger.save_event(__MODULE__, :nodedown, :nill, %{"node" => node})
    {:noreply, state}
  end
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warn ["#{inspect self()}... terminate"]
    :ok
  end
end
