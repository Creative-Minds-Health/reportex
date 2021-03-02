defmodule Xlsx.SrsWeb.Suive.Collector do
  use GenServer
  require Logger

  # alias Elixlsx.Sheet
  # alias Elixlsx.Workbook
  # alias Xlsx.Logger.LibLogger, as: LibLogger
  alias Xlsx.SrsWeb.Suive.Concat, as: Concat
  alias Xlsx.Date.Date, as: DateLib

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
  def handle_call({:concat, data}, _from, %{"diagnosis_template" => diagnosis_template, "progress" => progress}=state) do
    send(progress, :documents)
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
  def handle_cast(:generate, %{"diagnosis_template" => diagnosis_template, "progress" => progress, "params" => params}=state) do
    send(progress, {:update_status, :writing})
    #Logger.info ["generar archivo: #{inspect diagnosis_template}"]
    python_path = :filename.join(:code.priv_dir(:xlsx), "lib/python/srs_web/consult/first_level") |> String.to_charlist()
<<<<<<< HEAD
    {:ok, pid} = :python.start([{:python_path, python_path}, {:python, 'python'}])

=======
    {:ok, pid} = :python.start([{:python_path, python_path}, {:python, 'python3.7'}])
    file_name = DateLib.file_name_date("-") <> ".xlsx"
    file_path = :filename.join(:code.priv_dir(:xlsx), "assets/report/")
>>>>>>> 65ff16fe08e10f8206d83a3e3e9eed794b924f4b
    json = Poison.encode!(%{
      "consults" => diagnosis_template,
      "data" => %{
        "pathTemplate" => :filename.join(:code.priv_dir(:xlsx), "lib/python/srs_web/consult/first_level/SUIVE-400.xlsx"),
        "logo" => :filename.join(:code.priv_dir(:xlsx), "assets/logoSuive.png"),
        "params" => Map.put(get_params(params), "institution_name", "SECRETARÍA DE SALUD"),
        "path" => :filename.join(file_path, file_name)
      }
    })
    response = :python.call(pid, :rep, :initrep, [json])
    case Map.get(response, 'success', :false) do
      :true -> send(progress, {:done, file_path, file_name})
      _-> Logger.error ["paso mal"]
    end
    #Logger.info ["r: #{inspect r}"]
    #send(progress, {:done, file_path})
    {:noreply, state}
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{inspect msg}"
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
  def get_date_now(:undefined, separator) do
    today = DateTime.utc_now
    [today.year, today.month, today.day]
    Enum.join [get_number(today.day), get_number(today.month), today.year], separator
  end
  #
  # def get_date_now(date, separator) do
  #   [date.year, date.month, date.day]
  #   Enum.join [get_number(date.day), get_number(date.month), date.year], separator
  # end
  #
  def get_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end

  def get_number(number) do
    number;
  end

  def get_params(params) do
    [state | _] = get_state(Map.get(params, "state", :nil))
    [jurisdiction | _] = get_jurisdiction(state["_id"], Map.get(params, "jurisdiction", :nil))
    [clue | _] = get_clue(Map.get(params, "clue", :nil))

    response = %{"state_id" => state["_id"], "state" => state["name"], "jurisdiction_id" => jurisdiction["key"], "jurisdiction" => jurisdiction["name"], "clueName" => clue["name"], "institution_name" => clue["institution_name"], "municipality" => clue["municipality_name"], "municipality_key" => clue["municipality_key"], "clue" => params["clue"], "startDate" => get_dates(params["startDate"]), "endDate" => get_dates(params["endDate"])}

    case clue["municipality_key"] != "" do
      true ->
        [locality | _] = get_locality(clue["municipality_key"])
        Map.put(response, "location", locality["name"])
      _ -> response
    end
  end

  def get_state(state) do
    Mongo.find(:mongo, "states", %{"_id" => state}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_jurisdiction(_state_id, :nil) do
    [%{"_id" => "", "name" => ""}]
  end
  def get_jurisdiction(state_id, key) do
    Mongo.find(:mongo, "jurisdictions", %{"state_id" => state_id, "key" => key}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_clue(:nil) do
    [%{"name" => "", "institution_name" => "", "municipality_name" => "", "municipality_key" => ""}]
  end
  def get_clue(clue) do
    Mongo.find(:mongo, "cies", %{"_id" => clue}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_locality(municipality) do
    Mongo.find(:mongo, "localities", %{"municipality_key" => municipality}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_dates(date) do
    [month, day, year] = String.split(date, "/")
    %{"day" => day, "month" => month, "year" => year}
  end
end
