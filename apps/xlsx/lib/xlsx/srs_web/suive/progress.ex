defmodule Xlsx.SrsWeb.Suive.Progress do
  use GenServer
  require Logger

  alias Xlsx.Date.Date, as: DateLib
  alias Xlsx.Cluster.Listener, as: Listener
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
  def handle_info({:done , file_name}, %{"res_socket" => res_socket, "parent" => parent, "socket_id" => socket_id}=state) do
    # map = Application.get_env(:xlsx, :srs_gcs)
    # date = DateTime.now!("America/Mexico_City")
    # time = DateLib.string_time(date, "-")
    # new_map =
    #   Map.put(map, "file", :filename.join(File.cwd!(), file_name))
    #   |> Map.put("destination", Map.get(map, "destination") <> file_name <> "_" <> time  <> ".xlsx")
    #   |> Map.put("expires", Map.get(map, "expires", 1))
    # # {:ok, response} = NodeJS.call({"modules/gcs/upload-url-file.js", :uploadUrlFile}, [Poison.encode!(new_map)], timeout: 30_000)
    # {:ok, json_response} = Poison.encode(Map.put(%{}, "socket_id", socket_id))
    # #:gen_tcp.send(res_socket, json_response)
    # LibLogger.save_event(__MODULE__, :upload_xlsx, socket_id, %{"destination" => new_map["destination"]})
    # LibLogger.send_progress(res_socket, json_response)
    # Logger.info ["El collector terminó de juntar la información y lo escribio en python: #{inspect file_name}"]
    {:ok, json_response} = Poison.encode(Map.put(%{}, "url", file_name) |> Map.put("socket_id", socket_id))
    :gen_tcp.send(res_socket, json_response)
    send(parent, :kill)
    {:noreply, Map.put(state, "status", :done)}
  end
  def handle_info({:update_status, status}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "status", status), progress_timeout}
  end
  def handle_info(:documents, %{"documents" => documents}=state) do
    # Logger.info ["sssss: #{inspect documents}"]
    {:noreply, Map.put(state, "documents", documents + 1), 500}
  end
  def handle_info({:update_total, total}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "total", total) |> Map.put("status", :working), progress_timeout}
  end
  def handle_info(:timeout, %{:progress_timeout => progress_timeout, "status" => status, "res_socket" => res_socket, "documents" => documents, "total" => total, "socket_id" => socket_id}=state) do
    # Logger.info ["sssss: #{inspect documents}"]
    # Logger.info ["total: #{inspect total}"]
    # Logger.info ["percent: #{inspect trunc((documents * 100) / total)}"]
    map = case status do
      :waiting -> %{"message" => "Calculando progreso"}
      :working -> %{"message" => "Consultando información...", "Porcentaje" => trunc((documents * 100) / total)}
      :writing -> %{"message" => "Generando archivo excel..."}
      _-> %{}
    end
    {:ok, date} = DateTime.now("America/Mexico_City")
    {:ok, response} = Poison.encode(Map.put(map, "status", "doing") |> Map.put("socket_id", socket_id) |> Map.put("date_last_update", format_date(date)))
    LibLogger.send_progress(res_socket, response)
    #:gen_tcp.send(res_socket, response)
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

  defp number_to_string(number) do
    number
      |> Integer.to_char_list
      |> Enum.reverse
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse
  end
end
