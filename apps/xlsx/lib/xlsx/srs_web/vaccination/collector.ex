defmodule Xlsx.SrsWeb.Vaccination.Collector do
  use GenServer
  require Logger

  alias Elixlsx.Sheet
  alias Elixlsx.Workbook
  alias Xlsx.Logger.LibLogger, as: LibLogger
  alias Xlsx.Date.Date, as: DateLib
  alias Xlsx.Report.Report, as: ReportLib
  alias Xlsx.SrsWeb.Vaccination.Vaccination, as: Vaccination

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @impl true
  def handle_call({:concat, records, documents}, _from, %{"rows" => rows, "progress" => progress}=state) do
    style_record = records
    |> Stream.map(&(
      for item <- &1,
        into: [],
        do: [item, font: "Arial", size: 10, align_horizontal: :left, wrap_text: true]
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
  def handle_cast(:generate, %{"query" => query, "rows" => rows, "columns" => columns, "parent" => _parent, "progress" => progress, "socket_id" => socket_id}=state) do
    date_now = DateTime.now!("America/Mexico_City")
    LibLogger.save_event(__MODULE__, :generating_xlsx, socket_id, %{})
    send(progress, {:update_status, :writing})
    widths = ReportLib.col_widths(3, columns)
    new_rows = for {item, i} <- Enum.with_index(rows),
      do: ["", [i + 1, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 10]] ++ item

    sheet = %Sheet{
      name: "Resultados",
      rows: [[], [], [], [], [], [], [], []] ++ [["", ""] ++ columns] ++ new_rows,
      merge_cells: [{"D1", "G5"}],
      col_widths: widths,
      row_heights: %{9 => 30}
    }



    |> Sheet.set_cell("C7", "Usuario capturó:", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :right, font: "Arial", size: 12)
    |> Sheet.set_cell("E7", "Día de cita:", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :right, font: "Arial", size: 12)
    |> Sheet.set_cell("G7", "Día de asistencia:", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :right, font: "Arial", size: 12)
    |> Sheet.set_cell("I7", "SEDE de vacunación:", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :right, font: "Arial", size: 12)

    |> Sheet.set_cell("B9", "#", bg_color: "#d1d5da", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 12)
    |> Sheet.set_cell("D1", "Asistencia vacunación contra COVID-19  (Educación)", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 15)
    file_name = DateLib.string_date(date_now, "-")
    file_path = :filename.join(:code.priv_dir(:xlsx), "assets/report/")
    Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to(:filename.join(file_path, file_name))
    LibLogger.save_event(__MODULE__, :done_xlsx, socket_id, %{})
    send(progress, {:done, file_name, file_path})
    # GenServer.cast(self(), :stop)
    {:noreply, Map.put(state, "rows", rows)}
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
    # Logger.warning ["#{inspect self()}... terminate collector"]
    :ok
  end

  # def get_patient_fullname(query) do
  #   case Map.get(query, "$or", []) do
  #     [] -> "Sin filtro"
  #     [%{"patient.fullname" => %{"$options" => _, "$regex" => fullname}}|_] -> fullname
  #   end
  # end
end
