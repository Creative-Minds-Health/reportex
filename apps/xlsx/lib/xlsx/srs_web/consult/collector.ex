defmodule Xlsx.SrsWeb.Consult.Collector do
  use GenServer
  require Logger

  alias Elixlsx.Sheet
  alias Elixlsx.Workbook
  alias Xlsx.Logger.LibLogger, as: LibLogger
  alias Xlsx.Date.Date, as: DateLib
  alias Xlsx.Report.Report, as: ReportLib
  alias Xlsx.SrsWeb.Consult.Consult, as: Consult

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
        do: [item, font: "Arial", size: 10, align_horizontal: :left, wrap_text: true, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]]]
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
    date = DateLib.string_date(date_now, "/")
    time = DateLib.string_time(date_now, ":")
    LibLogger.save_event(__MODULE__, :generating_xlsx, socket_id, %{})
    send(progress, {:update_status, :writing})
    widths = ReportLib.col_widths(3, columns)
    new_rows = for {item, i} <- Enum.with_index(rows),
      do: ["", [i + 1, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 10, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]]]] ++ item

    sheet = %Sheet{
      name: "Resultados",
      rows: [[], [], [], []] ++ [["", ""] ++ columns] ++ new_rows,
      merge_cells: [{"E1", "W2"}],
      col_widths: widths,
      row_heights: %{5 => 70}
    }
    |> Sheet.set_cell("B5", "No.", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 9, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]])
    |> Sheet.set_cell("E1", "REGISTRO DIARIO DE PACIENTES EN CONSULTA EXTERNA (" <> date <> " " <> time <> ")", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 15)
    file_name = Consult.file_name(query)
    file_path = :filename.join(:code.priv_dir(:xlsx), "assets/report/")
    Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to(:filename.join(file_path, file_name))
    LibLogger.save_event(__MODULE__, :done_xlsx, socket_id, %{})
    send(progress, {:done, file_name, file_path, date_now})
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
