defmodule Xlsx.Request do
  use GenServer
  require Logger

  alias Xlsx.Mnesia.Node, as: MNode
  alias Xlsx.Decode.Query, as: DQuery
  alias Xlsx.Cluster.Listener, as: Listener
  alias Xlsx.Logger.Logger, as: XLogger
  alias Xlsx.Mnesia.Socket, as: MSocket

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    GenServer.cast(self(), :listener)
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:listener, %{"lsocket" => lsocket, "parent" => parent}=state) do
    {:ok, socket} = :gen_tcp.accept(lsocket)
    XLogger.save_event(Node.self(), __MODULE__, :nill, :tcp_accepted, %{})
    GenServer.cast(parent, :create_child)
    :ok = :inet.setopts(socket,[{:active,:once}])
    {:noreply, Map.put(state, "socket", socket), 300_000};
  end
  def handle_cast(:stop, %{"socket" => socket}=state) do
    Logger.warning ["aquiiiiiiiiiiii"]
    :ok=:gen_tcp.close(socket)
    Logger.warning ["sss #{inspect self()},#{inspect socket}... tcp_closed"]
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
  def handle_info({:tcp, res_socket, data}, %{"socket" => socket}=state) do
    :ok=:inet.setopts(socket,[{:active, :once}])
    data_decode = Poison.decode!(data) |> DQuery.decode()
    XLogger.save_event(Node.self(), __MODULE__, :tcp_message, Map.get(data_decode, "socket_id", :nill), data_decode)
    case MNode.next_node() do
      :undefined ->
        Logger.warning ["Eres el turno número... "]
        MSocket.save_socket(res_socket, self(), data_decode, MSocket.empty_sockets(), :waiting)
      node ->
        GenServer.cast({Listener, node["node"]}, {:generate_report, %{"res_socket" => res_socket, "data" => data_decode, "request" => self()}})
    end
    {:noreply, Map.put(state, "data", data) |> Map.put("res_socket", res_socket)}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{"collector" => collector}=state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{inspect msg}"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

end
