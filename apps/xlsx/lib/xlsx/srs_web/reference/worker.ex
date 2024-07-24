defmodule Xlsx.SrsWeb.Reference.Worker do
  use GenServer
  require Logger

  alias Xlsx.SrsWeb.Reference.Reference, as: Reference

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    # Logger.info "Worker was created..."
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
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:run, skip, _limit, documents}, %{"query" => query, "rows" => rows, "collector" => collector, "parent" => parent, "collection" => collection}=state) do
    cursor = Mongo.aggregate(:mongo, collection, query ++ [%{"$skip" => skip}, %{"$limit" => documents}], [timeout: 60_000])
    {:ok, _date} = DateTime.now("America/Mexico_City")
    records = cursor
      |> Stream.map(&(
        Reference.iterate_fields(&1, rows)
      ))
      |> Enum.to_list()
    {:ok, _date2} = DateTime.now("America/Mexico_City")
    :ok = GenServer.call(collector, {:concat, records, documents})
    :ok = GenServer.call(parent, :waiting_status)
    # Logger.info ["documents... #{inspect documents}"]
    send(parent, {:run_by_worker, self()})
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Logger.warning ["#{inspect self()} worker... terminate"]
    :ok
  end
end
