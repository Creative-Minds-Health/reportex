defmodule Xlsx.Ors.Product.BilledConsumption.Worker do
  use GenServer
  require Logger

  alias Xlsx.Ors.Product.BilledConsumption.Parser, as: Parser

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
    cursor = Mongo.aggregate(:mongo, collection, query ++ [%{"$skip" => skip}, %{"$limit" => documents}], [allow_disk_use: true, timeout: 60_000])
    {:ok, _date} = DateTime.now("America/Mexico_City")
    records = cursor
      |> Stream.map(&(
        get_compare(&1, collection)
      ))
      |> Enum.to_list()
    {:ok, _date2} = DateTime.now("America/Mexico_City")
    :ok = GenServer.call(collector, {:concat, collection, records, documents})
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

  defp get_compare(item, "requests") do
    provider_id = Map.get(item, "provider", %{}) |> Map.get("_id", :nil)
    #Logger.info ["provider_id: #{inspect provider_id}"]
    compare = {
      Map.get(item, "folio", :nil),
      Map.get(item, "antel_code", :nil),
      Map.get(item, "provider", %{}) |> Map.get("code", :nil),
      Map.get(item, "provider", %{}) |> Map.get("_id", :nil),
      Map.get(item, "assign", :nil)
    }
    Map.put(item, "compare", compare)
  end
  defp get_compare(item, "remissions") do
    tmp_id = Map.get(item, "provider", %{}) |> Map.get("_id", "")
    remission_provider_id = case {tmp_id, is_bitstring(tmp_id)} do
      {"", _} -> ""
      {_, false} ->
        {:ok, value} = BSON.ObjectId.encode(tmp_id)
        value
      {_, _} -> ""
    end
    compare = {
      Map.get(item, "request_folio", :nil),
      Map.get(item, "antel_code", :nil),
      Map.get(item, "provider", %{}) |> Map.get("code", :nil),
      remission_provider_id,
      Map.get(item, "assign", :nil)
    }
    Map.put(item, "compare", compare)
  end
end
