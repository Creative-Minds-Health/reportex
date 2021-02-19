defmodule Xlsx.Listener do
  use GenServer
  require Logger

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, "connected", :false) |> Map.put("master", Application.get_env(:xlsx, :master)), name: __MODULE__)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "Listener is running..."
    {:ok, state, 2_000}
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
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, %{"connected" => :true, "master" => master}=state) do
    Logger.info "slave node connected to master node #{inspect master}"
    {:noreply, state}
  end
  def handle_info(:timeout, %{"connected" => :false, "master" => master}=state) do
    Logger.info "master #{inspect master}"

    {:noreply, Map.put(state, "connected", Node.connect master), 2_000}
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
