defmodule Xlsx.SrsWeb.Collector do
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
    Logger.info "Collector is running..."
    {:ok, state}
  end

  @impl true
  def handle_call({:concat, records, documents}, _from, %{"rows" => rows, "progress" => progress}=state) do
    style_record = records
    |> Stream.map(&(
      for item <- &1,
        into: [],
        do: [item, font: "Arial", size: 12, align_horizontal: :left]
    ))
    |> Enum.to_list()
    send(progress, {:documents, documents})
    {:reply, :ok, Map.put(state, "rows", rows ++ style_record)}
  end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:generate, %{"rows" => rows, "columns" => columns, "period" => period, "parent" => parent, "progress" => progress}=state) do
    Logger.info "Generate..."
    send(progress, {:update_status, :writing})
    sheet = %Sheet{
      name: "Resultados",
      rows: [[], [], [], []] ++[columns] ++ rows,
      merge_cells: [{"A1", "D3"},{"E2", "T2"}, {"G3", "I3"}]
    }
    # |> Sheet.set_cell("A1", "Imagen", font: "Arial", size: 12, align_horizontal: :center, align_vertical: :center)
    |> Sheet.set_cell("E2", "Reporte de egresos", bold: true, font: "Arial", size: 19, align_horizontal: :center, align_vertical: :center)
    |> Sheet.set_cell("F3", "Periodo:", bold: true, font: "Arial", size: 12, align_horizontal: :left)
    |> Sheet.set_cell("G3", get_date_now(period["$gte"], "/") <> " - " <> get_date_now(period["$lte"], "/"), font: "Arial", size: 12, align_horizontal: :left)
    |> Sheet.set_col_width("A", 17.0)
    |> Sheet.set_col_width("B", 20.0)
    |> Sheet.set_col_width("C", 17.0)
    |> Sheet.set_col_width("D", 17.0)
    |> Sheet.set_col_width("E", 17.0)
    |> Sheet.set_col_width("F", 17.0)
    |> Sheet.set_col_width("G", 17.0)
    |> Sheet.set_col_width("H", 17.0)
    |> Sheet.set_col_width("I", 14.0)
    |> Sheet.set_col_width("J", 14.0)
    |> Sheet.set_col_width("K", 14.0)
    |> Sheet.set_col_width("L", 14.0)

    file_name = "Reporte_egresos_" <> get_date_now(:undefined, "-") <> ".xlsx"
    Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to(file_name)

    Logger.info "Finish..."
    send(progress, {:done, file_name})
    {:noreply, :ok, Map.put(state, "rows", rows)}
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(_msg, state) do
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

  def get_date_now(:undefined, separator) do
    today = DateTime.utc_now
    [today.year, today.month, today.day]
    Enum.join [get_number(today.day), get_number(today.month), today.year], separator
  end

  def get_date_now(date, separator) do
    [date.year, date.month, date.day]
    Enum.join [get_number(date.day), get_number(date.month), date.year], separator
  end

  def get_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end

  def get_number(number) do
    number;
  end
end
