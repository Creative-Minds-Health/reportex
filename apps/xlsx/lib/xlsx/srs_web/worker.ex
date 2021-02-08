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
      value -> [value | iterate_fields(item, t)]
    end
  end

  def get_value(item, [], _field, _default_value) do
    item
  end

  def get_value(item, [_h|_t], "patient|nationality|key", default_value) do
    case Map.get(Map.get(item, "patient", %{}), "is_abroad", :undefined) do
      1 ->
        Map.get(item, "patient", %{}) |> Map.get("nationality", %{}) |> Map.get("key", "")
      _ -> default_value

    end
  end

  def get_value(item, [h|t], "patient|splited_age", default_value) do
    splited_age = Map.get(item, "patient", %{}) |> Map.get("splited_age", %{})
    {:multi, Xlsx.SrsWeb.ParserA.age(Map.get(splited_age, "years", 0), Map.get(splited_age, "months", 0), Map.get(splited_age, "days", 0), default_value)}
  end

  # def get_value(item, [h|t], "patient|was_born_hospital|key", default_value) do
  #   splited_age = Map.get(item, "patient", %{}) |> Map.get("splited_age", %{})
  #
  #   Xlsx.SrsWeb.ParserA.was_born_hospital(Map.get(item, "patient", %{}) |> Map.get("was_born_hospital", %{}) |> Map.get("key", :undefined), Map.get(splited_age, "years", 0), Map.get(splited_age, "months", 0), default_value)
  # end

  def get_value(_item, [_h|_t], "patient|claveEdad", _default_value) do
    ""
  end

  def get_value(item, [h|t], field, default_value) do
    case Map.get(item, h, :undefined) do
      :undefined -> default_value
      value -> get_value(value, t, field, default_value)
    end
  end

  # def get_row_names([]) do
  #   []
  # end
  #
  # def get_row_names([h|t]) do
  #   [[h["name"], bold: true, font: "Arial", size: 12]|get_row_names(t)]
  # end

end
