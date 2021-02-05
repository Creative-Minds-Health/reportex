defmodule Xlsx.Reportex do
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
    Logger.info "Reportex GenServer is running..."
    GenServer.cast(self(), :listener)
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:listener, %{lsocket: lsocket, parent: parent}=state) do
    {:ok, socket} = :gen_tcp.accept(lsocket)
    Logger.info ["Pid #{inspect __MODULE__} socket accepted"]
    GenServer.cast(parent, :create_child)
    :ok = :inet.setopts(socket,[{:active,:once}])
    {:noreply, Map.put(state, :socket, socket), 300_000};
  end
  def handle_cast(:stop, %{socket: socket}=state) do
    :ok=:gen_tcp.close(socket)
    Logger.warning ["#{inspect self()},#{inspect socket}... tcp_closed"]
    {:stop, :normal, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _reason}, state) do
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, %{socket: sock}=state) do
    data_decode = Poison.decode!(data)
    :ok=:inet.setopts(sock,[{:active, :once}])

    cursor = Mongo.aggregate(:mongo, "egresses", data_decode["query"])
    # cursor
    # |> Enum.to_list()
    # |> IO.inspect

    [%{"$match" => query} | _] = data_decode["query"];
    count = Mongo.count(:mongo, "egresses", query)

    [fields|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data_decode["report_key"]})
    |> Enum.to_list()

    report_config = fields["config"]

    names = get_row_names(fields["rows"])

    rows = cursor
      |>
        Stream.map(&(
          iterate_fields(&1, fields["rows"])
        ))
      |> Enum.to_list()

    sheet = %Sheet{
      name: "Resultados",
      rows: [names] ++ rows
    }
    # |> Sheet.set_cell("A5", "Double border", border: [bottom: [style: :double, color: "#cc3311"]])

    Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to("egresses.xlsx")

    response = "egress.xlsx"
    :ok = :gen_tcp.send(socket, response)
    Logger.info ["Respuesta #{inspect response}"]
    {:noreply, Map.put(state, :response_socket, socket), 300_000}
  end
  def handle_info({:tcp, socket, data}, %{socket: sock}=state) do
    Logger.info ["Socket message #{inspect data}"]
    :ok=:inet.setopts(sock,[{:active, :once}])
    {:noreply, Map.put(state, :response_socket, socket), 300_000}
  end
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warning ["#{inspect self()}... terminate"]
    :ok
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

  def get_row_names([]) do
    []
  end

  def get_row_names([h|t]) do
    [[h["name"], bold: true, font: "Arial", size: 12]|get_row_names(t)]
  end

end
