defmodule Xlsx.SrsWeb.Suive.Collector do
  use GenServer
  require Logger

  # alias Elixlsx.Sheet
  # alias Elixlsx.Workbook
  # alias Xlsx.Logger.LibLogger, as: LibLogger
  alias Xlsx.SrsWeb.Suive.Concat, as: Concat

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
  def handle_call(:generate, _from, %{"diagnosis_template" => diagnosis_template}=state) do
    Logger.info ["diagnosis_template #{inspect diagnosis_template}"]
  end
  def handle_call({:concat, data}, _from, %{"diagnosis_template" => diagnosis_template}=state) do
    {:reply, :ok, Map.put(state, "diagnosis_template", Concat.concat_data(data, diagnosis_template, Map.keys(diagnosis_template)))}
  end
  # def handle_call({:concat, records, documents}, _from, %{"rows" => rows, "progress" => progress}=state) do
  #   style_record = records
  #   |> Stream.map(&(
  #     for item <- &1,
  #       into: [],
  #       do: [item, font: "Arial", size: 12, align_horizontal: :left]
  #   ))
  #   |> Enum.to_list()
  #   send(progress, {:documents, documents})
  #   {:reply, :ok, Map.put(state, "rows", rows ++ style_record)}
  # end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  # def handle_cast(:generate, %{"rows" => rows, "columns" => columns, "query" => query, "parent" => parent, "progress" => progress, "socket_id" => socket_id}=state) do
  #   LibLogger.save_event(__MODULE__, :generating_xlsx, socket_id, %{})
  #   send(progress, {:update_status, :writing})
  #   widths = for index <- 1..110, into: %{}, do:  {index, 30}
  #   sheet = %Sheet{
  #     name: "Resultados",
  #     rows: [[], [], [], [], [], [], []] ++[columns] ++ rows,
  #     merge_cells: [{"C2", "J2"}],
  #     col_widths: widths
  #   }
  #   |> Sheet.set_cell("C2", "Reporte de egresos", bold: true, font: "Arial", size: 19, align_horizontal: :center, align_vertical: :center)
  #   |> Sheet.set_cell("C4", "Periodo:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center)
  #   |> Sheet.set_cell("D4", get_date_now(query["stay.exit_date"]["$gte"], "/") <> " - " <> get_date_now(query["stay.exit_date"]["$lte"], "/"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("E4", "Jurisdicción:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("F4", Map.get(query, "jurisdiction.key", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("G4", "Unidad médica:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("H4", Map.get(query, "clue", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("I4", "Folio de egreso:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("J4", Map.get(query, "folio", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("C5", "Nombre de paciente, CURP o póliza:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("D5", get_patient_fullname(query), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("E5", "Motivo de egreso:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("F5", Map.get(query, "stay.shipping_reason.key", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("G5", "Afección principal diagnostico (CIE-10):", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("H5", Map.get(query, "affections.main_diagnosis.key_diagnosis", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("I5", "Servicio de ingreso:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("J5", Map.get(query, "stay.admission_service.key", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("C6", "Estatus:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("D6", Map.get(query, "status.key", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   |> Sheet.set_cell("E6", "Código CIE-9 de procedimiento:", bold: true, font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #   |> Sheet.set_cell("F6", Map.get(query, "procedures.diagnosis.key_diagnosis", "Sin filtro"), font: "Arial", size: 12, align_horizontal: :left, wrap_text: true, align_vertical: :center,)
  #
  #   file_name = get_date_now(:undefined, "-")
  #   Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to(file_name)
  #
  #   LibLogger.save_event(__MODULE__, :done_xlsx, socket_id, %{})
  #   send(progress, {:done, file_name})
  #   # GenServer.cast(self(), :stop)
  #   {:noreply, Map.put(state, "rows", rows)}
  # end
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
  #
  # def get_date_now(:undefined, separator) do
  #   today = DateTime.utc_now
  #   [today.year, today.month, today.day]
  #   Enum.join [get_number(today.day), get_number(today.month), today.year], separator
  # end
  #
  # def get_date_now(date, separator) do
  #   [date.year, date.month, date.day]
  #   Enum.join [get_number(date.day), get_number(date.month), date.year], separator
  # end
  #
  # def get_number(number) when number < 10 do
  #   "0" <> Integer.to_string(number);
  # end
  #
  # def get_number(number) do
  #   number;
  # end
end
