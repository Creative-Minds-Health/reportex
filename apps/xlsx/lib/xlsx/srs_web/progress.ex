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
  def handle_info({:done , file_name}, %{:progress_timeout => progress_timeout, "res_socket" => res_socket}=state) do
    {:ok, response} = Poison.encode(%{"url" => file_name})
    :gen_tcp.send(res_socket, response)
    {:noreply, Map.put(state, "status", :done)}
  end
  def handle_info({:update_status, status}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "status", status), progress_timeout}
  end
  def handle_info({:documents, new_documents}, %{:progress_timeout => progress_timeout, "documents" => documents}=state) do
    {:noreply, Map.put(state, "documents", new_documents + documents), 500}
  end
  def handle_info({:update_total, total}, %{:progress_timeout => progress_timeout}=state) do
    {:noreply, Map.put(state, "total", total) |> Map.put("status", :working), progress_timeout}
  end
  def handle_info(:timeout, %{:progress_timeout => progress_timeout, "status" => status, "res_socket" => res_socket, "documents" => documents, "total" => total}=state) do
    map = case status do
      :waiting -> %{"message" => "Calculando progreso"}
      :working -> %{"message" => "Progreso " <> Integer.to_string(documents) <> " de " <> Integer.to_string(total), "Porcentaje" => trunc((documents * 100) / total)}
      :writing -> %{"message" => "Generando archivo excel..."}
      _-> %{}
    end
    {:ok, response} = Poison.encode(Map.put(map, "total", total))
    Logger.info ["#{inspect response}"]
    :gen_tcp.send(res_socket, response)
    {:noreply, state, progress_timeout}
  end
  def handle_info(_msg, state) do
    Logger.info "Progress UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.warning ["#{inspect self()}... terminate"]
    :ok
  end
end
