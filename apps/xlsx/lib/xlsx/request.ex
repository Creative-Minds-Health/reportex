defmodule Xlsx.Request do
  use GenServer
  require Logger

  alias Xlsx.Mnesia.Node, as: MNode
  alias Xlsx.Decode.Query, as: DQuery
  alias Xlsx.Cluster.Listener, as: Listener
  alias Xlsx.Logger.LibLogger, as: LibLogger
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
    {:ok, Map.put(state, "data", %{})}
  end

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:listener, %{"lsocket" => lsocket, "parent" => parent}=state) do
    {:ok, socket} = :gen_tcp.accept(lsocket)
    LibLogger.save_event(__MODULE__, :tcp_accepted, :nill, %{})
    GenServer.cast(parent, :create_child)
    :ok = :inet.setopts(socket,[{:active,:once}])
    {:noreply, Map.put(state, "socket", socket), 300_000};
  end
  def handle_cast({:stop, node}, %{"socket" => socket, "data" => data}=state) do
    # Logger.info "stop node #{inspect socket}"
    # Logger.info "stop node #{inspect data}"
    LibLogger.save_event(__MODULE__, :kill_request, Map.get(data, "socket_id", :nill), %{})
    MNode.decrement_doing(node)
    :ok=:gen_tcp.close(socket)
    {:stop, :normal, state}
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:start_listener, data}, state) do
    pid = GenServer.call({Listener, data["node"]}, {:generate_report, %{"res_socket" => data["socket"], "data" => data["data"], "request" => self()}})

    {:noreply, Map.put(state, "data", data["data"]) |> Map.put("res_socket", data["socket"]) |> Map.put("node", data["node"]) |> Map.put("report", pid)}
  end
  def handle_info({:tcp_closed, _reason}, %{"res_socket" => res_socket, "node" => node, "report" => report}=state) do
    GenServer.cast({Listener, node}, {:kill, report})
    # GenServer.cast(self(), :stop)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _reason}, state) do
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end
  def handle_info({:tcp, res_socket, data}, %{"socket" => socket}=state) do
    :ok=:inet.setopts(socket,[{:active, :once}])
    data_decode = Poison.decode!(data) |> DQuery.decode()
    LibLogger.save_event(__MODULE__, :tcp_message, Map.get(data_decode, "socket_id", :nill), data_decode)
    new_state = case MNode.next_node() do
      :undefined ->
        Logger.warning ["Eres el turno número..."]
        MSocket.save_socket(res_socket, self(), data_decode, MSocket.empty_sockets(), :waiting)
        Map.put(state, "data", data_decode) |> Map.put("res_socket", res_socket)
      node ->
        pid = GenServer.call({Listener, node["node"]}, {:generate_report, %{"res_socket" => res_socket, "data" => data_decode, "request" => self()}})
        Map.put(state, "data", data_decode) |> Map.put("res_socket", res_socket) |> Map.put("node", node["node"]) |> Map.put("report", pid)
    end
    {:noreply, new_state}
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
