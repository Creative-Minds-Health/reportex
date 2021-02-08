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
  def handle_call({:concat, records}, _from, %{"rows" => rows}=state) do
    # sheet = %Sheet{
    #   name: "Resultados",
    #   rows: rows ++ records
    # }
    # Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to("egresses.xlsx")
    # {:stop, :normal, Map.put(state, "rows", rows ++ records)}
    {:reply, :ok, Map.put(state, "rows", rows ++ records)}
  end
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:generate, %{"rows" => rows, "columns" => columns}=state) do
    Logger.info "Generate..."
    sheet = %Sheet{
      name: "Resultados",
      rows: [columns] ++ rows
    } |> Sheet.set_col_width("A", 17.0)
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
    Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to("egresses.xlsx")
    Logger.info "Finish..."
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
end
