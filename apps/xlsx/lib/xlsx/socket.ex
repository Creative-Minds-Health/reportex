defmodule Xlsx.Socket do
  use GenServer
  require Logger

  alias Xlsx.Mnesia.Socket, as: MSocket
  alias Xlsx.SrsWeb.ProgressTurn, as: ProgressTurn
  alias Xlsx.Mnesia.Worker, as: MWorker
  alias Xlsx.Mnesia.Node, as: MNode

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, "workers", %{}), name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "GenServer is running..."
    case :gen_tcp.listen(4_000, [:binary, {:packet, :raw}, {:active, false}, {:reuseaddr, true}] ) do
      {:ok,lsocket} ->
        GenServer.cast(__MODULE__, :create_child)
        {:ok, Map.put(state, "lsocket", lsocket)}
      {:error, reason}->
        {:stop, reason}
    end
  end
  def create_child() do
    GenServer.cast(__MODULE__, :create_child)
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:create_child, state) do
    {:ok, pid} = Xlsx.Request.start(%{"lsocket" => state["lsocket"], "parent" => self()})
    Process.monitor(pid)

    {:noreply, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:next, %{}}, state) do
    # Logger.warning ["Ya no hay nada"]
    {:noreply, state}
  end

  def handle_info({:next, {_, socket, request, data, _turno, _date, _status}}, state) do
    # GenServer.cast(request, :start)

    case MNode.next_node() do
      :undefined ->
        []
      node ->
        :ok = MSocket.update_status(socket, {:waiting, :doing})
        :ok = MSocket.update_turns()
        send(request, {:start_listener, %{"socket" => socket, "data" => data, "node" => node["node"]}})
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do

    #Se valida si el socket que se murio es el que estaba trabajando
    case MSocket.check_kill_pid(pid) do
      {:atomic, []} ->
        send(self(), {:next, get_next_socket()})
      {:atomic, [{_, socket, _request, _, _, _, status}|_t]} ->
        :ok=:gen_tcp.close(socket)
        case status do
          :doing ->
            MSocket.delete(socket)
            send(self(), {:next, get_next_socket()})
          :waiting ->
            MSocket.delete(socket)
            :ok = MSocket.update_turns()
        end
    end

    {:noreply, state}
  end
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.warning ["#{inspect __MODULE__}", " terminate. pid: #{inspect self()}", ", project: ", state["project"]]
    :ok
  end

  def get_next_socket() do
    case MSocket.next_socket() do
      {:ok, socket} -> socket
      _ -> %{}
    end
  end
end
