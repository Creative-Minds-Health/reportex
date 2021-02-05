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
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:listener, %{lsocket: lsocket, parent: parent}=state) do
    {:ok, socket} = :gen_tcp.accept(lsocket)
    Logger.info ["Pid #{inspect __MODULE__} socket accepted"]
    GenServer.cast(parent, :create_child)
    :ok = :inet.setopts(socket,[{:active,:once}])
    {:noreply, Map.put(state, :socket, socket), 300_000};
  end
  def handle_cast(:stop, %{socket: socket}=state) do
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

  def handle_info({:tcp, socket, data}, %{socket: sock}=state) do
    Logger.info ["message #{inspect data}"]
    :ok=:inet.setopts(sock,[{:active, :once}])
    n_workers = 5
    limit = 10
    workers = for index <- 1..n_workers,
      {:ok, pid} = Xlsx.SrsWeb.Worker.start(%{:parent => self()}),
      {:ok, date} = DateTime.now("America/Mexico_City"),
      Process.monitor(pid),
      into: %{},
      do: {pid, %{date: date}}
      send(self(), :kill_workers)
    {:noreply, Map.put(state, :workers, workers)}
  end

  def handle_info(:kill_workers, %{workers: workers}=state) do
    Process.sleep(5000)
    for pid <- Map.keys(workers),
      GenServer.cast(pid, :stop),
      do: ""
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.warning ["#{inspect pid} worker... deleted"]
    {:noreply, Map.put(state, :workers, Map.delete(state[:workers], pid))}
  end
  def handle_info({:tcp, socket, data}, %{socket: sock}=state) do
    Logger.info ["Socket message #{inspect data}"]
    :ok=:inet.setopts(sock,[{:active, :once}])
    {:noreply, Map.put(state, :response_socket, socket), 300_000}
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
