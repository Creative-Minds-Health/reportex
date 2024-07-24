defmodule Xlsx.Ors.Product.BilledConsumption.Collector do
  use GenServer
  require Logger

  alias Elixlsx.Sheet
  alias Elixlsx.Workbook
  alias Xlsx.Logger.LibLogger, as: LibLogger
  alias Xlsx.Date.Date, as: DateLib
  alias Xlsx.Report.Report, as: ReportLib
  alias Xlsx.SrsWeb.Consult.Consult, as: Consult
  alias Xlsx.Ors.Product.BilledConsumption.Parser, as: Parser

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
  def handle_call({:concat, "requests", records, documents}, _from, %{"requests" => requests, "progress" => progress}=state) do
    # style_record = get_style_record(records)
    send(progress, {:documents, documents})
    {:reply, :ok, Map.put(state, "requests", requests ++ records)}
  end
  def handle_call({:concat, "remissions", records, documents}, _from, %{"remissions" => remissions, "progress" => progress}=state) do
    # style_record = get_style_record(records)
    send(progress, {:documents, documents})
    {:reply, :ok, Map.put(state, "remissions", remissions ++ records)}
  end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:merge, %{"requests" => requests, "remissions" => remissions, "fields" => fields}=state) do
    sales = increase_requests(requests, remissions)
    rows = sales
      |> Enum.to_list()
      |> Stream.map(&(
        Parser.iterate_fields(&1, fields)
      ))
      |> Enum.to_list()

    GenServer.cast(self(), :generate)
    {:noreply, Map.put(state, "rows", rows)}
    # {:noreply, state}
  end
  @impl true
  def handle_cast(:generate, %{"query" => query, "rows" => rows, "columns" => columns, "parent" => _parent, "progress" => progress, "socket_id" => socket_id, "params" => params}=state) do
    date_now = DateTime.now!("America/Mexico_City")
    date = DateLib.string_date(date_now, "/")
    time = DateLib.string_time(date_now, ":")
    LibLogger.save_event(__MODULE__, :generating_xlsx, socket_id, %{})
    send(progress, {:update_status, :writing})
    widths = ReportLib.col_widths(3, columns)
    headers = get_headers(params, {date, time})
    new_rows = for {item, i} <- Enum.with_index(rows),
      do: ["", [i + 1, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 10, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]]]] ++ item
    sheet = %Sheet{
      name: "Resultados",
      rows: [[], [], [], []] ++ headers ++ [["", ""] ++ columns] ++ new_rows,
      merge_cells: [{"B1", "M2"}],
      col_widths: %{3 => 25, 4 => 20, 5 => 15, 6 => 20, 7 => 20, 8 => 20, 9 => 30, 10 => 20, 11 => 15, 12 => 15, 13 => 40},
      row_heights: %{11 => 70}
    }
    |> Sheet.set_cell("B11", "No.", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 9, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]])
    |> Sheet.set_cell("B1", "CONSUMO FACTURADO", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 15)
    # file_name = Consult.file_name(query)
    file_name = "productos_" <> DateLib.file_name_date("-") <> ".xlsx"
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

  defp get_style_record(records) do
    records
    |> Stream.map(&(
      for item <- &1,
        into: [],
        do: [item, font: "Arial", size: 10, align_horizontal: :left, wrap_text: true, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]]]
    ))
    |> Enum.to_list()
  end

  defp increase_requests([], remissions) do
    Logger.info ["Termina increase_requests: #{inspect length(remissions)}"]

    #Logger.info ["Remisiones: #{inspect length(remissions)}"]
    remissions
  end
  defp increase_requests([h|t], remissions) do
    case increase_value_request(h, remissions) do
      {:nil, request, %{}} ->
        [ request | increase_requests(t, remissions)]
      {:ok, request, remission} ->
        new_remissions = delete_remission(remission, remissions)
        [ request | increase_requests(t, new_remissions)]
    end
  end

  defp increase_value_request(request, []) do
    {:nil, request, %{}}
  end
  defp increase_value_request(request, [h|t]) do
    case compare(Map.get(request, "compare"), Map.get(h, "compare")) do
      true ->
        quantity = Map.get(request, "quantity") + Map.get(h, "quantity")
        consumed = Map.get(request, "consumed") + Map.get(h, "consumed")
        {:ok, Map.put(request, "quantity", quantity) |> Map.put("consumed", consumed), h}
      _ -> increase_value_request(request, t)
    end
  end


  defp compare({:nil, :nil, :nil, :nil, :nil}, {:nil, :nil, :nil, :nil, :nil}) do
    false
  end

  defp compare({folio, antel_code, provider_code, provider_id, assign}, {folio, antel_code, provider_code, provider_id, assign}) do
    true
  end
  defp compare({_, _, _, _, _}, {_, _, _, _, _}) do
    false
  end

  defp get_headers(params, {date, time}) do
    folio = Map.get(params, "folio", %{}) |> Map.get("folio", "N/A")
    billed_folio = Map.get(params, "billed_folio", %{}) |> Map.get("folio", "N/A")
    warehouse = Map.get(params, "hospital", %{}) |> Map.get("name", "N/A")
    from_date =  Map.get(params, "from_date", "N/A")
    to_date =  Map.get(params, "to_date", "N/A")
    product = Map.get(params, "product", %{}) |> Map.get("antel_code", "N/A")
    date_title = [ [""] ++ [""] ++ ["Fecha de creación del Excel:"] ++ [date <> " " <> time] ] ++ [[""]] ++  [ [""] ++ [""] ++ ["Filtros utilizados para generar Excel"] ]
    filters_c1 = [ [""] ++ [""] ++ ["Folio:"] ++ [folio] ++ [""] ++ ["Folio de facturación:"] ++ [billed_folio] ++ [""] ++ ["Producto:"] ++ [product]]
    filters_c2 = [ [""] ++ [""] ++ ["Almacén:"] ++ [warehouse] ++ [""] ++ ["De fecha de cirugía:"] ++ [from_date] ++ [""] ++ ["Hasta fecha de cirugía:"] ++ [to_date]]
    date_title ++ filters_c1 ++ filters_c2 ++ [[""]]
  end

  defp delete_remission(_, []) do [] end
  defp delete_remission(remission, [h|t]) do
    case compare(Map.get(remission, "compare"), Map.get(h, "compare")) do
      :true ->
        t
      _ -> [h | delete_remission(remission, t)]
    end
  end

  defp count_remisisons([], counter) do
    Logger.info ["Checados son: #{inspect counter}"]
  end
  defp count_remisisons([h|t], counter) do
    case Map.get(h, "checked", :nil) do
      :true -> count_remisisons(t, counter + 1)
      _ -> count_remisisons(t, counter)
    end
  end
end
