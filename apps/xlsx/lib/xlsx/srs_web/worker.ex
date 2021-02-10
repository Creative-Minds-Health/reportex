defmodule Xlsx.SrsWeb.Worker do
  use GenServer
  require Logger


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
        iterate_fields(&1, rows)
      ))
      |> Enum.to_list()
    {:ok, _date2} = DateTime.now("America/Mexico_City")
    Logger.info ["records #{inspect records}"]
    :ok = GenServer.call(collector, {:concat, records})
    :ok = GenServer.call(parent, :waiting_status)
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

  def iterate_fields(_item, []) do
    []
  end

  def iterate_fields(item, [h|t]) do
    case get_value(item, h["field"] |> String.split("|"), h["field"], h["default_value"]) do
      {:multi, value} ->
        value ++ iterate_fields(item, t);
      value ->
        [value | iterate_fields(item, t)]
    end
  end

  def get_value(item, [], _field, _default_value) do
    item
  end

  def get_value(item, [_h|_t], "patient|nationality|key", default_value) do
    Xlsx.SrsWeb.ParserA.nationality(Map.get(Map.get(item, "patient", %{}), "is_abroad", 0), Map.get(item, "patient", %{}) |> Map.get("nationality", %{}) |> Map.get("key", ""), default_value)

  end

  def get_value(item, [_h|_t], "patient|splited_age", default_value) do
    splited_age = Map.get(item, "patient", %{}) |> Map.get("splited_age", %{})
    {:multi, Xlsx.SrsWeb.ParserA.age(Map.get(splited_age, "years", 0), Map.get(splited_age, "months", 0), Map.get(splited_age, "days", 0), default_value)}
  end

  def get_value(item, [_h|_t], "patient|dh", default_value) do
    {:multi, Xlsx.SrsWeb.ParserA.dh(Map.get(item, "patient", %{}) |> Map.get("dh", []), default_value)}
  end

  def get_value(item, [_h|_t], "stay|origin|unit_clue|key", default_value) do
    Xlsx.SrsWeb.ParserA.clues(Map.get(item, "stay", %{}) |> Map.get("origin", %{}) |> Map.get("unit_clue", %{}) |> Map.get("key", :undefined), Map.get(item, "clue", :undefined), default_value)
  end

  def get_value(item, [_h|_t], "comorbidity|comorbidities", _default_value) do
    {:multi, Xlsx.SrsWeb.ParserA.comorbidities(Map.get(item, "comorbidity", :undefined), Map.get(item, "comorbidity", %{}) |> Map.get("comorbidities", []))}
  end

  def get_value(item, [_h|_t], "procedures", _default_value) do
    {:multi, Xlsx.SrsWeb.ParserA.procedures(Map.get(item, "procedures", []))}
  end

  def get_value(item, [_h|_t], "product", _default_value) do
    {:multi, Xlsx.SrsWeb.ParserA.product(Map.get(item, "product", []))}
  end

  def get_value(item, [h|t], field, default_value) do
    case Map.get(item, h, :undefined) do
      :undefined -> default_value
      value -> get_value(value, t, field, default_value)
    end
  end
end
