defmodule Xlsx.SrsWeb.Worker do
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
    Logger.info "Worker was created..."
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:run, skip, limit}, %{"query" => query, "rows" => rows, "collector" => collector, "parent" => parent}=state) do
    Logger.warning ["paginacion: #{inspect [%{"$skip" => skip}, %{"$limit" => limit}]}"]
    cursor = Mongo.aggregate(:mongo, "egresses", query ++ [%{"$skip" => skip}, %{"$limit" => limit}])
    records = cursor
      |> Stream.map(&(
        iterate_fields(&1, rows)
      ))
      |> Enum.to_list()
    :ok = GenServer.call(collector, {:concat, records})
    :ok = GenServer.call(parent, :waiting_status)
    send(parent, :run)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{inspect msg}"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{"parent" => parent}=state) do
    Logger.warning ["#{inspect self()} worker... terminate"]
    :ok
  end




  def iterate_fields(item, []) do
    []
  end

  def iterate_fields(item, [h|t]) do
    [
      get_value(item, h["field"] |> String.split("|"), h["field"], h["default_value"]) | iterate_fields(item, t)
    ]
  end

  def get_value(item, [], field, default_value) do
    item
  end

  def get_value(item, [h|t], "patient|nationality|key", default_value) do
    case Map.get(Map.get(item, "patient", %{}), "is_abroad", :undefined) do
      1 ->
        patient = Map.get(item, "patient", %{});
        nationality = Map.get(patient, "nationality", %{})
        Map.get(nationality, "key", "")
      _ -> default_value

    end
  end

  def get_value(item, [h|t], field, default_value) do
    case Map.get(item, h, :undefined) do
      :undefined -> ""
      value -> get_value(value, t, field, default_value)
    end
  end

  def get_row_names([]) do
    []
  end

  def get_row_names([h|t]) do
    [[h["name"], bold: true, font: "Arial", size: 12]|get_row_names(t)]
  end

end
