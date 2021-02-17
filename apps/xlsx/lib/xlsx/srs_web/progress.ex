defmodule Xlsx.SrsWeb.Progress do
  use GenServer
  require Logger

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
    map = Application.get_env(:xlsx, :srs_gcs)
    date = DateTime.now!("America/Mexico_City")
    time = get_number(date.hour) <> "-" <> get_number(date.minute) <> "-" <> get_number(date.second)
    new_map =
      Map.put(map, "file", :filename.join(File.cwd!(), file_name))
      |> Map.put("destination", Map.get(map, "destination") <> file_name <> "_" <> time  <> ".xlsx")
      |> Map.put("expires", Map.get(map, "expires", 1))
    Logger.info ["new_map: #{inspect new_map}"]
    {:ok, response} = NodeJS.call({"modules/gcs/upload-url-file.js", :uploadUrlFile}, [Poison.encode!(new_map)], timeout: 30_000)
    {:ok, json_response} = Poison.encode(Map.put(response, "socket_id", socket_id))
    :gen_tcp.send(res_socket, json_response)
    #GenServer.cast(self(), :stop)
    send(parent, :kill)
    {:noreply, Map.put(state, "status", :done)}
  end
  def handle_info({:update_status, status}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "status", status), progress_timeout}
  end
  def handle_info({:documents, new_documents}, %{"documents" => documents}=state) do
    {:noreply, Map.put(state, "documents", new_documents + documents), 500}
  end
  def handle_info({:update_total, total}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "total", total) |> Map.put("status", :working), progress_timeout}
  end
  def handle_info(:timeout, %{:progress_timeout => progress_timeout, "status" => status, "res_socket" => res_socket, "documents" => documents, "total" => total, "socket_id" => socket_id}=state) do
    map = case status do
      :waiting -> %{"message" => "Calculando progreso"}
      :working -> %{"message" => "Progreso " <> Integer.to_string(documents) <> " de " <> Integer.to_string(total), "Porcentaje" => trunc((documents * 100) / total)}
      :writing -> %{"message" => "Generando archivo excel..."}
      _-> %{}
    end
    {:ok, response} = Poison.encode(Map.put(map, "total", total) |> Map.put("status", "doing") |> Map.put("socket_id", socket_id))
    # Logger.info ["#{inspect response}"]
    :gen_tcp.send(res_socket, response)
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
end
