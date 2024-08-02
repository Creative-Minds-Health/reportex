defmodule Xlsx.Ors.Request.ListConsumed.Collector do
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
    results = parse_records(records, [])
    style_record = results
    |> Stream.map(&(
      for item <- &1,
        into: [],
        do: [item, font: "Arial", size: 10, align_horizontal: :left, wrap_text: true, border: [bottom: [style: :thin, color: "#000000"], top: [style: :thin, color: "#000000"], left: [style: :thin, color: "#000000"], right: [style: :thin, color: "#000000"]]]
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
  def handle_cast(:generate, %{"query" => query, "rows" => rows, "columns" => columns, "parent" => _parent, "progress" => progress, "socket_id" => socket_id, "params" => params}=state) do
    date_now = DateTime .now!("America/Mexico_City")
    date = DateLib.string_date(date_now, "/")
    time = DateLib.string_time(date_now, ":")
    LibLogger.save_event(__MODULE__, :generating_xlsx, socket_id, %{})
    send(progress, {:update_status, :writing})
    new_columns = add_columns(columns)
    widths = ReportLib.col_widths(3, new_columns)
    new_rows = []
    #a = get_rows(rows)
    new_rows = for {item, i} <- Enum.with_index(rows),
      do: ["", [i + 1, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 10, border: [bottom: [style: :thin, color: "#000000"], top: [style: :thin, color: "#000000"], left: [style: :thin, color: "#000000"], right: [style: :thin, color: "#000000"]]]] ++ item

    params_list = Map.to_list(params)
    filters_1 = get_filters(params_list, {0, 5})
    filters_2 = get_filters(params_list, {5, 10})
    filters_3 = get_filters(params_list, {10, 13})

    sheet = %Sheet{
      name: "Resultados",
      #rows: [[], [], [], ["", "", a, b, c, d], [], []] ++[["", ""] ++ columns] ++ new_rows,
      rows: [[], [], [], filters_1, filters_2, filters_3, [] ] ++[["", ""] ++ new_columns] ++ new_rows,
      merge_cells: [{"B1", "H2"}],
      col_widths: widths,
      row_heights: %{8 => 70}
    }
    |> Sheet.set_cell("B8", "No.", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 9, border: [bottom: [style: :thin, color: "#000000"], top: [style: :thin, color: "#000000"], left: [style: :thin, color: "#000000"], right: [style: :thin, color: "#000000"]])
    |> Sheet.set_cell("B1", "Reporte de Cirugías realizadas con consumo (" <> date <> " " <> time <> ")", bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 15)



    # file_name = Consult.file_name(query)
    file_name = DateLib.file_name_date("-") <> ".xlsx"
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

  defp get_filters(params, {index, stop}) do
    get_filters(params, {index, stop}, ["", ""])
  end
  defp get_filters(_, {stop, stop}, acc) do
    acc
  end
  defp get_filters(params, {index, stop}, acc) do
    {key, value} = Enum.at(params, index)
    new_acc = acc ++ [
      [key, {:rotate_text, nil}, {:width, 30}, {:bold, false}, {:wrap_text, true}, {:align_vertical, :center}, {:align_horizontal, :left}, {:font, "Arial"}, {:size, 10}]
    ] ++ [
      [value, {:bg_color, "#E8ECF1"}, {:rotate_text, nil}, {:width, 30}, {:bold, true}, {:wrap_text, true}, {:align_vertical, :center}, {:align_horizontal, :center}, {:font, "Arial"}, {:size, 10}]
    ]
    get_filters(params, {index + 1, stop}, new_acc)

  end

  defp get_rows(rows) do
    get_rows(rows, 1)
  end
  defp get_rows([h|t], index) do
    # new_rows = for {item, i} <- Enum.with_index(rows),
    #   do: ["", [i + 1, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 10, border: [bottom: [style: :thin, color: "#000000"], top: [style: :thin, color: "#000000"], left: [style: :thin, color: "#000000"], right: [style: :thin, color: "#000000"]]]] ++ item
  end

  defp parse_records([], acc) do
    acc
  end
  defp parse_records([h|t], acc) do
    {fields, products} = split_products(h, [], [])
    results = merge_products(products, fields, 0)
    parse_records(t, acc ++ results)
  end


  defp split_products([], acc, products) do
    {acc, products}
  end
  defp split_products([{:products, products} | t], acc, _) do
    split_products(t, acc, products)
  end
  defp split_products([h|t], acc, products) do
    split_products(t, acc ++ [h], products)
  end


  defp merge_products([], fields, _index) do
    []
  end
  defp merge_products([h|t], fields, 0) do
    antel_code = Map.get(h, "antel_code")
    description = Map.get(h, "description")
    consumed = Map.get(h, "consumed")
    [ fields ++ [antel_code, description, consumed] | merge_products(t, fields, 1) ]
  end
  defp merge_products([h|t], fields, index) do
    antel_code = Map.get(h, "antel_code")
    description = Map.get(h, "description")
    consumed = Map.get(h, "consumed")
    list = ["", "", "", "", "", "", "", "", "", "", "", "", "", ""]
    [ list ++ [antel_code, description, consumed] | merge_products(t, fields, 1) ]
  end

  defp add_columns(add_columns) do
    columns = for item <- ["Descripción", "Cantidad consumida"],
      into: [],
      do: [item, bg_color: "#d1d5da", rotate_text: :nil, width: 30,  bold: true,  wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 12]
    add_columns ++ columns
  end



end
