defmodule Xlsx.SrsWeb.ProgressTurn do
  use GenServer
  require Logger

  alias Xlsx.Mnesia.Socket, as: MSocket
  alias Xlsx.Decode.Query, as: DQuery

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    report_config = Application.get_env(:xlsx, :report)
    #{:ok, state}
    {:ok, Map.put(state, :progress_timeout, report_config[:progress_timeout]), report_config[:progress_timeout]}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end
  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end


  @impl true
  def handle_info(:timeout, %{:progress_timeout => progress_timeout}=state) do
    case MSocket.waiting_sockets() do
      [] -> [];
      list ->
        for {_, socket, _, data, turn, _, _} <- list,
          data_decode = Poison.decode!(data) |> DQuery.decode(),
          {:ok, date} = DateTime.now("America/Mexico_City"),
          {:ok, response} = Poison.encode(%{"status" => "waiting", "message" => "Turno: " <> Integer.to_string(turn), "date_last_update" => format_date(date), "socket_id" => data_decode["socket_id"]}),
        do:
        # Logger.warning ["response #{inspect   response}"]
        :gen_tcp.send(socket, response)
    end
    {:noreply, state, progress_timeout}
  end
  def handle_info(_msg, state) do
    Logger.info "Progress UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Logger.warning ["#{inspect self()}... terminate progress"]
    :ok
  end

  def format_date(date) do
    {{year, month, day}, {hour, minutes, seconds}} = NaiveDateTime.to_erl(date)
    get_number(day) <> "/" <> get_number(month) <> "/" <> get_number(year) <> " " <> get_number(hour) <> ":" <> get_number(minutes) <> ":" <> get_number(seconds)
  end

  def get_number(number) when number < 10 do
    "0" <> Integer.to_string(number)
  end

  def get_number(number) do
    Integer.to_string(number)
  end
end
