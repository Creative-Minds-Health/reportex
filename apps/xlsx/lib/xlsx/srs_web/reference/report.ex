defmodule Xlsx.SrsWeb.Reference.Report do
  use GenServer
  require Logger

  alias Xlsx.Mongodb.Mongodb, as: Mongodb
  alias Xlsx.SrsWeb.Reference.Progress, as: Progress
  alias Xlsx.SrsWeb.Reference.Collector, as: Collector
  alias Xlsx.SrsWeb.Reference.Worker, as: Worker
  alias Xlsx.Mnesia.Worker, as: MWorker
  alias Xlsx.Logger.LibLogger, as: LibLogger

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    GenServer.cast(self(), :start)
    {:ok, Map.put(state, "collector", %{}) |> Map.put("total", 0) |> Map.put("page", 1) |> Map.put("skip", 0) |> Map.put("status", :doing)}
  end

  @impl true
  def handle_call(:waiting_status, {from, _}, state) do
    :ok = MWorker.update_status(from, {:occupied, :waiting})
    {:reply, :ok, state}
  end
  def handle_call({:update_status, status}, _from, state) do
    {:reply, :ok, Map.put(state, "status", status)}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:start, %{"res_socket" => res_socket, "data" => data}=state) do
    {:ok, progress} = Progress.start(%{"parent" => self(), "status" => :waiting, "res_socket" => res_socket, "total" => 0, "documents" => 0, "socket_id" => data["socket_id"]})
    Process.monitor(progress)
    [record|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data["report_key"]}) |> Enum.to_list()


    new_state = Map.put(state, "record", record) |> Map.put("progress", progress) |> Map.put("count_data", data["count"])
    LibLogger.save_event(__MODULE__, :report_start, Map.get(data, "socket_id", :nill), new_state)

    send(self(), {:get_total, data["levels"]})
    # send(self(), {:iterate, data["levels"]})
    # send(self(), {:count, Mongodb.count_query(data, "attentions")})
    {:noreply, new_state}
  end
  def handle_cast(:stop, %{"data" => data}=state) do
    LibLogger.save_event(__MODULE__, :kill_report, Map.get(data, "socket_id", :nill), %{})
    {:stop, :normal, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true

  def handle_info({:get_total, levels}, %{"count_data" => count_data, "progress" => progress, "record" => record, "data" => data}=state) do
    total = Mongodb.count_query_aggregate(count_data, count_data["collection"])
    send(progress, {:update_total, total})

    {:ok, collector} = Collector.start(%{"parent" => self(), "rows" => [], "columns" => name_columns(record["rows"]), "progress" => progress, "socket_id" => data["socket_id"], "total" => total})
    Process.monitor(collector)

    send(self(), {:iterate, levels})
    {:noreply,  Map.put(state, "total", total) |> Map.put("documents", record["config"]["documents"]) |> Map.put("collector", collector)}
  end


  def handle_info({:iterate, []}, %{"collector" => collector}=state) do
    case MWorker.empty_workers(self()) do
      :true ->
        GenServer.cast(collector, :generate)
      _ -> []
    end
    {:noreply, state}
  end
  def handle_info({:iterate, [h|t]}, %{"count_data" => count_data}=state) do
    # Logger.info ["iterateeeeeeeeeeeeeeeeee"]
    [%{"$match" => match} | complement] = count_data["query"]
    send(self(), {:count, h})
    {:noreply, Map.put(state, "levels", t) |> Map.put("page", 1) |> Map.put("skip", 0) |> Map.put("total_level", Mongodb.count_query_aggregate(Map.put(count_data, "query", [%{"$match" => Map.put(match, "from.level", h["level"])} | complement]), count_data["collection"]))}
  end

  def handle_info({:count, _level}, %{"data" => data, "progress" => progress, "res_socket" => res_socket, "total" => total}=state) when total === 0 do
    {:ok, response} = Poison.encode(Map.put(%{}, "total", 0) |> Map.put("status", "empty") |> Map.put("socket_id", data["socket_id"]))
    :gen_tcp.send(res_socket, response)
    GenServer.cast(progress, :stop)
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end
  def handle_info({:count, level}, %{"record" => record, "data" => data, "page" => page, "collector" => collector, "total" => total, "total_level" => total_level}=state) when total > 0 do
    {:ok, date} = DateTime.now("America/Mexico_City")
    # Logger.info ["total_leveltotal_leveltotal_leveltotal_level #{inspect total_level}"]

    for _index <- 1..get_n_workers(total_level, round(total_level / record["config"]["documents"]), record["config"]["workers"]),
      {:ok, pid} = Worker.start(%{"parent" => self(), "rows" => rows_with_out_specials(record["rows"]), "query" => level["query"], "collector" => collector, "collection" => level["collection"]}),
      Process.monitor(pid),
      :ok = MWorker.dirty_write(pid, :waiting, date, self()),
      into: %{},
      do: {pid, %{"date" => date, "status" => :waiting}}
    LibLogger.save_event(__MODULE__, :count, Map.get(data, "socket_id", :nill), state)

    send(self(), {:run, page * record["config"]["documents"]})
    {:noreply, state}
  end

  def handle_info({:run_by_worker, from}, %{"total" => total, "skip" => skip, "total_level" => total_level}=state) when skip >= total_level do
    GenServer.cast(from, :stop)
    {:noreply, state}
  end
  def handle_info({:run_by_worker, _from}, %{"page" => page, "documents" => documents, "total" => total, "skip" => skip, "total_level" => total_level}=state) do
    msg = Integer.to_string(skip) <> "-" <> Integer.to_string(total)
    {:ok, _response} = Poison.encode(%{"progreso..." => msg})
    send(self(), {:run, page * documents})
    {:noreply, state}
  end

  def handle_info({:run, _limit}, %{"total" => total, "skip" => skip, "data" => data, "total_level" => total_level}=state) when skip >= total_level do
    LibLogger.save_event(__MODULE__, :run_all, Map.get(data, "socket_id", :nill), state)
    {:noreply, state}
  end

  def handle_info({:run, limit}, %{"total" => total, "skip" => skip, "documents" => documents, "page" => page, "total_level" => total_level}=state) when limit <= total_level do
    # Logger.info ["limit <= total"]
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
  def handle_info({:run, limit}, %{"page" => page, "total" => total, "skip" => skip, "total_level" => total_level}=state)  when limit > total_level do
    # Logger.info ["limit > total"]
    new_state = case MWorker.next_worker() do
      {:ok, pid} ->
        send(pid, {:run, skip, total_level, (total_level - skip)})
        send(self(), {:run, total_level})
        :ok = MWorker.update_status(pid, {:waiting, :occupied})
        Map.put(state, "skip", limit) |> Map.put("page", page + 1)
      _ ->
        state
    end
    {:noreply, new_state}
  end

  def handle_info(:kill, %{"status" => status, "res_socket" => res_socket, "data" => data}=state) do
    case status do
      :doing ->
        :ok = LibLogger.send_progress(res_socket, Poison.encode!(Map.put(%{}, "socket_id", data["socket_id"]) |> Map.put("status", "error")))
      _-> []
    end
    kill_processes(["collector", "progress"], state)
    for {_XlsxWorker, pid, _status, _date, _report} <- MWorker.get_workers(self()),
      GenServer.cast(pid, :stop),
      {:atomic, :ok} = MWorker.delete(pid),
      do: []
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{"status" => status}=state) when status === :done do
    send(self(), :kill)
    {:noreply, state}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{"levels" => levels}=state) do
    {:atomic, :ok} = MWorker.delete(pid)
    case MWorker.empty_workers(self()) do
      :true ->
        send(self(), {:iterate, levels})
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
      do: [item["name"], bold: true, wrap_text: true, align_vertical: :center, align_horizontal: :center, font: "Arial", size: 12, border: [bottom: [style: :medium, color: "#000000"], top: [style: :medium, color: "#000000"], left: [style: :medium, color: "#000000"], right: [style: :medium, color: "#000000"]]]
  end

  def rows_with_out_specials(rows) do
    for item <- rows, item["special"] === :false, do: item
  end

  def kill_processes([], _state) do
    :ok
  end
  def kill_processes([h | t], state) do
    case Map.get(state, h, :nil) do
      :nill -> kill_processes(t, state)
      pid ->
        LibLogger.save_event(__MODULE__, String.to_atom("kill_" <> h), Map.get(state, "data", %{}) |> Map.get("socket_id", :nill), %{})
        GenServer.cast(pid, :stop)
        kill_processes(t, state)
    end
  end
end
