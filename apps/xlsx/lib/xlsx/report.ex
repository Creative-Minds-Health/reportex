defmodule Xlsx.Report do
  use GenServer
  require Logger

  alias Xlsx.Mnesia.Socket, as: MSocket
  alias Xlsx.Decode.Query, as: DQuery
  alias Xlsx.Mongodb.Mongodb, as: Mongodb
  alias Xlsx.SrsWeb.Progress, as: Progress
  alias Xlsx.SrsWeb.Collector, as: Collector
  alias Xlsx.SrsWeb.Worker, as: Worker
  alias Xlsx.Mnesia.Worker, as: MWorker

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
    {:ok, Map.put(state, "collector", %{}) |> Map.put("total", 0) |> Map.put("page", 1) |> Map.put("skip", 0)}
  end

  @impl true
  def handle_call(:waiting_status, {from, _}, state) do
    :ok = MWorker.update_status(from, {:occupied, :waiting})
    {:reply, :ok, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:start, %{"res_socket" => res_socket, "data" => data}=state) do
    data_decode = Poison.decode!(data) |> DQuery.decode()
    {:ok, progress} = Progress.start(%{"parent" => self(), "status" => :waiting, "res_socket" => res_socket, "total" => 0, "documents" => 0, "socket_id" => data_decode["socket_id"]})
    Process.monitor(progress)

    [record|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data_decode["report_key"]}) |> Enum.to_list()
    send(self(), {:count, Mongodb.count_query(data_decode, record["collection"])})
    {:noreply, Map.put(state, "data", data_decode) |> Map.put("record", record) |> Map.put("progress", progress)}
  end
  def handle_cast(:listener, %{"lsocket" => lsocket, "parent" => parent}=state) do
    {:ok, socket} = :gen_tcp.accept(lsocket)
    Logger.info ["Pid #{inspect __MODULE__} socket accepted"]
    GenServer.cast(parent, :create_child)
    :ok = :inet.setopts(socket,[{:active,:once}])
    {:noreply, Map.put(state, "socket", socket), 300_000};
  end
  def handle_cast(:stop, %{"socket" => socket}=state) do
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

  def handle_info({:count, 0}, state) do
    Logger.warning ["No hay resultados en el query"]
    {:noreply, state}
  end
  def handle_info({:count, total}, %{"progress" => progress, "record" => record, "data" => data, "page" => page}=state) do
    send(progress, {:update_total, total})
    [%{"$match" => query} | _] = data["query"];
    {:ok, date} = DateTime.now("America/Mexico_City")
    {:ok, collector} = Collector.start(%{"parent" => self(), "rows" => [], "columns" => name_columns(record["rows"]), "period" => query["stay.exit_date"], "progress" => progress})
    Process.monitor(collector)
    for _index <- 1..get_n_workers(total, round(total / record["config"] ["documents"]), record["config"]["workers"]),
      {:ok, pid} = Worker.start(%{"parent" => self(), "rows" => rows_with_out_specials(record["rows"]), "query" => data["query"], "collector" => collector, "collection" => record["collection"]}),
      Process.monitor(pid),
      :ok = MWorker.dirty_write(pid, :waiting, date),
      into: %{},
      do: {pid, %{"date" => date, "status" => :waiting}}
    send(self(), {:run, page * record["config"]["documents"]})
    {:noreply, Map.put(state, "total", total) |> Map.put("documents", record["config"]["documents"]) |> Map.put("collector", collector)}
  end
  def handle_info({:socket_turn, 1}, %{"res_socket" => res_socket, "data" => data}=state) do

    MSocket.save_socket(res_socket, self(), data, 1, :doing)
    GenServer.cast(self(), :start)
    {:noreply, state}
  end
  def handle_info({:socket_turn, turn}, %{"res_socket" => res_socket, "data" => data}=state) do
    Logger.warning ["Eres el turno número... "]
    MSocket.save_socket(res_socket, self(), data, turn, :waiting)
    # save_socket(socket, data, turn, date);
    # creo que aquí debo empezar a ejecutar la funcion que mande el progreso de turno a los sockets encolados
    {:noreply, state}
  end

  def handle_info({:tcp, res_socket, data}, %{"socket" => socket}=state) do
    :ok=:inet.setopts(socket,[{:active, :once}])
    send(self(), {:socket_turn, MSocket.empty_sockets()})
    {:noreply, Map.put(state, "res_socket", res_socket) |> Map.put("data", data)}
  end


  def handle_info({:run_by_worker, from}, %{"total" => total, "skip" => skip}=state) when skip >= total do
    GenServer.cast(from, :stop)
    {:noreply, state}
  end
  def handle_info({:run_by_worker, _from}, %{"page" => page, "documents" => documents, "total" => total, "skip" => skip}=state) do
    msg = Integer.to_string(skip) <> "-" <> Integer.to_string(total)
    {:ok, _response} = Poison.encode(%{"progreso..." => msg})
    send(self(), {:run, page * documents})
    {:noreply, state}
  end

  def handle_info({:run, _limit}, %{"total" => total, "skip" => skip}=state) when skip >= total do
    Logger.warning "Se mandaron todos los registros"
    {:noreply, state}
  end

  def handle_info({:run, limit}, %{"total" => total, "skip" => skip, "documents" => documents, "page" => page}=state) when limit <= total do
    new_state = case MWorker.next_worker() do
      {:ok, pid} ->
        send(pid, {:run, skip, limit, documents})
        send(self(), {:run, (page + 1) * documents})
        :ok = MWorker.update_status(pid, {:waiting, :occupied})
        Map.put(state, "skip", limit) |> Map.put("page", page + 1)
      _ ->
        state
    end
    {:noreply, new_state}
  end
  def handle_info({:run, limit}, %{"page" => page, "total" => total, "skip" => skip, "documents" => _documents}=state)  when limit > total do
    new_state = case MWorker.next_worker() do
      {:ok, pid} ->
        send(pid, {:run, skip, total, (total - skip)})
        send(self(), {:run, total})
        :ok = MWorker.update_status(pid, {:waiting, :occupied})
        Map.put(state, "skip", limit) |> Map.put("page", page + 1)
      _ ->
        state
    end
    {:noreply, new_state}
  end

  # def handle_info({:DOWN, _ref, :process, collector, _reason}, %{"collector" => collector}=state) do
  #   Logger.warning ["#{inspect collector}... deleted collector"]
  #   Map.delete(state["collector"], collector)
  #   {:noreply, state}
  # end
  #
  # def handle_info({:DOWN, _ref, :process, progress, _reason}, %{"progress" => progress}=state) do
  #   Logger.warning ["#{inspect progress}... deleted progress"]
  #   Map.delete(state["progress"], progress)
  #   {:noreply, state}
  # end

  def handle_info(:kill, %{"collector" => collector, "progress" => progress}=state) do
    GenServer.cast(progress, :stop)
    GenServer.cast(collector, :stop)
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{"collector" => collector}=state) do
    {:atomic, :ok} = MWorker.delete(pid)
    case MWorker.empty_workers() do
      :true ->
        GenServer.cast(collector, :generate)
      _ -> []
    end
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{inspect msg}"
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  def get_n_workers(0, _round_total, _config_workers) do
    Logger.info ["Error en total"]
  end
  def get_n_workers(total, 0, config_workers) do
    get_n_workers(total, 1, config_workers)
  end
  def get_n_workers(_total, round_total, config_workers) do
    case round_total < config_workers do
      :true -> round_total
      :false ->  config_workers
    end
  end

  def name_columns(rows) do
    for item <- rows,
      into: [],
      do: [item["name"], bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 12, border: [bottom: [style: :thin, color: "#000000"], top: [style: :thin, color: "#000000"], left: [style: :thin, color: "#000000"], right: [style: :thin, color: "#000000"]]]
  end

  def rows_with_out_specials(rows) do
    for item <- rows, item["special"] === :false, do: item
  end
end
