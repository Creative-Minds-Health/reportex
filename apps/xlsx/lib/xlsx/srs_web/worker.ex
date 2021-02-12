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
    :ok = GenServer.call(collector, {:concat, records, documents})
    :ok = GenServer.call(parent, :waiting_status)
    Logger.info ["documents... #{inspect documents}"]
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

  def get_value(item, [_h|_t], "stay|additional_service", _default_value) do
    {:multi, Xlsx.SrsWeb.ParserA.additional_service(Map.get(item, "stay", %{}) |> Map.get("additional_service", []))}
  end

  def get_value(item, [_h|_t], "patient|curp", _default_value) do
    #{:ok, patient} = Poison.encode(Xlsx.Decode.Mongodb.decode(item["patient"]))
    #{:ok, stay} = Poison.encode(Xlsx.Decode.Mongodb.decode(item["stay"]))
    #{:ok, response} = NodeJS.call({"modules/sinba/bulk-load/egress/egress.helper.js", :validatePatientCurp}, [patient, stay])
    item["patient"]["curp"]
  end

  def get_value(item, [_h|_t], "stay|admission_date", _default_value) do
    case Map.get(item, "stay", %{}) |> Map.get("admission_date", :undefined) do
      :undefined -> ""
      date ->
        sinba_date(date)
    end
  end
  def get_value(item, [_h|_t], "stay|exit_date", _default_value) do
    case Map.get(item, "stay", %{}) |> Map.get("exit_date", :undefined) do
      :undefined -> ""
      date ->
        sinba_date(date)
    end
  end

  def get_value(item, [h|t], field, default_value) do
    case Map.get(item, h, :undefined) do
      :undefined -> default_value
      value -> get_value(value, t, field, default_value)
    end
  end

  def sinba_date(date) do
    #{:ok, json} = Poison.encode(%{"date" => DateTime.to_string(date)})
    #{:ok, response} = NodeJS.call({"modules/sinba/bulk-load/bulk-load.helper.js", :sinbaDate}, [json])
    # response["date"]
    DateTime.to_string(date)
  end
end
