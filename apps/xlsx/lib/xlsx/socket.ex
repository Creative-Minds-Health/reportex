defmodule Xlsx.Socket do
  use GenServer
  require Logger

  alias Xlsx.Mnesia.Socket, as: MSocket
  alias Xlsx.SrsWeb.ProgressTurn, as: ProgressTurn
  alias Xlsx.Mnesia.Worker, as: MWorker

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
    {:ok, pid} = Xlsx.Report.start(%{"lsocket" => state["lsocket"], "parent" => self()})
    {:ok, date} = DateTime.now("America/Mexico_City")
    Process.monitor(pid)

    {:ok, progress} = ProgressTurn.start(%{"parent" => self()})
    Process.monitor(progress)
    {:noreply, Map.put(state, "workers", Map.put(state["workers"], pid, %{"init_date" => date}))}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true

  def handle_info({:next, []}, state) do
    # Logger.warning ["Ya no hay nada"]
    {:noreply, state}
  end

  def handle_info({:next, {_, socket, report, _data, _turno, _date, _status}}, state) do
    :ok = MSocket.update_status(socket, {:waiting, :doing})
    :ok = MSocket.update_turns()
    GenServer.cast(report, :start)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Logger.warning ["#{inspect pid}... delete reporte"]

    #Se valida si el socket que se murio es el que estaba trabajando
    case MSocket.check_kill_pid(pid) do
      {:atomic, []} -> :undefined
      {:atomic, [{_, socket, report, _, _, _, status}|_t]} ->
        case status do
          :doing ->
            send(self(), :kill_workers)
            MSocket.delete(socket)
            send(self(), {:next, get_next_socket()})
          :waiting ->
            MSocket.delete(socket)
            :ok = MSocket.update_turns()
        end
    end

    {:noreply, Map.put(state, "workers", Map.delete(state["workers"], pid))}
  end

  def handle_info(:kill_workers, state) do
    case MWorker.get_workers() do
      [] -> [];
      list ->
        for {_, pid, _, _} <- list,
        {:atomic, :ok} = MWorker.delete(pid),
        do: GenServer.cast(pid, :stop)
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
      _ -> []
    end
  end
end
