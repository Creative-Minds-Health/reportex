defmodule Xlsx.Tmp do
  use GenServer
  require Logger

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, "workers", %{}), name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "Tmp is running...#{inspect self()}"
    GenServer.cast(self(), :listener)
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(msg, state) do
    Logger.warning ["Mensage #{inspect msg}"]
    {:noreply, state}
  end

  @impl true
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
