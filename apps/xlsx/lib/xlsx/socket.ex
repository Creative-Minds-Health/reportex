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
    {:ok, pid} = Xlsx.Request.start(%{"lsocket" => state["lsocket"], "parent" => self()})
    Process.monitor(pid)
    {:noreply, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    Logger.info "se murio el request"
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
end
