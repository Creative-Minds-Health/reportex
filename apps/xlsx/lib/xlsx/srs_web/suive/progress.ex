defmodule Xlsx.SrsWeb.Suive.Progress do
  use GenServer
  require Logger

  alias Xlsx.Date.Date, as: DateLib
  alias Xlsx.Logger.LibLogger, as: LibLogger

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
  def handle_info({:done , file_path, file_name}, %{"res_socket" => res_socket, "parent" => parent, "socket_id" => socket_id}=state) do
    map = Application.get_env(:xlsx, :srs_gcs)
    new_map =
      Map.put(map, "file", :filename.join(file_path, file_name))
      |> Map.put("destination", :filename.join(Map.get(map, "destination"), "suive/" <> file_name))
      |> Map.put("expires", Map.get(map, "expires", 1))
    {:ok, response} = NodeJS.call({"modules/gcs/upload-url-file.js", :uploadUrlFile}, [Poison.encode!(new_map)], timeout: 30_000)
    {:ok, json_response} = Poison.encode(Map.put(response, "socket_id", socket_id))
    LibLogger.save_event(__MODULE__, :upload_xlsx, socket_id, %{"destination" => new_map["destination"]})
    LibLogger.send_progress(res_socket, json_response)
    :ok = File.rm(:filename.join(file_path, file_name))
    send(parent, :kill)
    {:noreply, Map.put(state, "status", :done)}
  end
  def handle_info({:update_status, status}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "status", status), progress_timeout}
  end
  def handle_info(:documents, %{"documents" => documents}=state) do
    {:noreply, Map.put(state, "documents", documents + 1), 100}
  end
  def handle_info({:update_total, total}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "total", total) |> Map.put("status", :working), progress_timeout}
  end
  def handle_info(:timeout, %{:progress_timeout => progress_timeout, "status" => status, "res_socket" => res_socket, "documents" => documents, "total" => total, "socket_id" => socket_id}=state) do
    map = case status do
      :waiting -> %{"message" => "Calculando progreso"}
      :working ->
        percent = trunc((documents * 100) / total)
        %{"message" => "Porcentaje " <> Integer.to_string(percent) <> "%", "Porcentaje" => percent}
      :writing -> %{"message" => "Generando archivo excel..."}
      _-> %{}
    end
    {:ok, date} = DateTime.now("America/Mexico_City")
    {:ok, response} = Poison.encode(Map.put(map, "status", "doing") |> Map.put("socket_id", socket_id) |> Map.put("date_last_update", format_date(date)))
    LibLogger.send_progress(res_socket, response)
    {:noreply, state, progress_timeout}
  end
  def handle_info(_msg, state) do
    Logger.info "Progress UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  def get_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end

  def get_number(number) do
    Integer.to_string(number);
  end

  def format_date(date) do
    {{year, month, day}, {hour, minutes, seconds}} = NaiveDateTime.to_erl(date)
    get_number(day) <> "/" <> get_number(month) <> "/" <> get_number(year) <> " " <> get_number(hour) <> ":" <> get_number(minutes) <> ":" <> get_number(seconds)
  end

end
