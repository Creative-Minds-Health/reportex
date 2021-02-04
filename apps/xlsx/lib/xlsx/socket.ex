defmodule Xlsx.Socket do
  use GenServer
  require Logger
  alias Elixlsx.Sheet
  alias Elixlsx.Workbook

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, :workers, %{}), name: __MODULE__)
  end
  def get_document do
    cursor = Mongo.find(:mongo, "egresses", %{})
    fields = Mongo.find(:mongo, "reportex", %{"report_key" => "egresses"})
    [fields_new|_] = fields |>
      Stream.map(&(
        &1["rows"]
        # &1["patient"]["curp"]

      ))
    |> Enum.to_list()
    # cursor = Mongo.find(:mongo, "users", %{})
    rows = cursor
      |>
        Stream.map(&(
          iterate_fields(&1, fields_new)
        ))
      |> Enum.to_list()
    # IO.puts "#terminó"
    IO.puts "#{inspect rows}"
    Workbook.append_sheet(%Workbook{}, %Sheet{
      name: "Third",
      rows: rows
    }) |> Elixlsx.write_to("egresses.xlsx")

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

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "GenServer is running..."
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
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end
end
