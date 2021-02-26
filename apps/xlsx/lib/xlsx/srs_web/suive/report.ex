defmodule Xlsx.SrsWeb.Suive.Report do
  use GenServer
  require Logger

  alias Xlsx.Mongodb.Mongodb, as: Mongodb
  alias Xlsx.SrsWeb.Suive.Progress, as: Progress
  alias Xlsx.SrsWeb.Suive.Collector, as: Collector
  alias Xlsx.SrsWeb.Suive.Worker, as: Worker
  alias Xlsx.Mnesia.Worker, as: MWorker
  alias Xlsx.Logger.LibLogger, as: LibLogger
  alias Xlsx.SrsWeb.Suive.Suive, as: Suive

  # API
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    GenServer.cast(self(), :start)
    {:ok, Map.put(state, "collector", %{}) |> Map.put("total", 1) |> Map.put("page", 1) |> Map.put("skip", 0)}
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
  def handle_cast(:start, %{"res_socket" => res_socket, "data" => data, "total" => total}=state) do
    {:ok, progress} = Progress.start(%{"parent" => self(), "status" => :waiting, "res_socket" => res_socket, "total" => 0, "documents" => 0, "socket_id" => data["socket_id"]})
    Process.monitor(progress)
    [record|_] = Mongo.find(:mongo, "reportex", %{"report_key" => data["report_key"], "project" => data["project"]})
      |> Enum.to_list()
    new_state = Map.put(state, "record", record) |> Map.put("progress", progress)
    LibLogger.save_event(__MODULE__, :report_start, Map.get(data, "socket_id", :nill), new_state)
    send(self(), {:count, total})
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
  # def handle_info({:count, 0}, %{"progress" => progress, "socket_id" => socket_id, "res_socket" => res_socket}=state) do
  #   Logger.warning "count 0"
  #   {:ok, response} = Poison.encode(Map.put(%{}, "total", 0) |> Map.put("status", "empty") |> Map.put("socket_id", socket_id))
  #   :gen_tcp.send(res_socket, response)
  #   GenServer.cast(progress, :stop)
  #   GenServer.cast(self(), :stop)
  #   {:noreply, state}
  # end
  def handle_info({:count, total}, %{"progress" => progress, "record" => record, "data" => data, "page" => page}=state) do
    [%{"$match" => query} | _] = data["query"];
    {:ok, date} = DateTime.now("America/Mexico_City")
    dates = Suive.date_range(query, record["config"]["days_range"])
    n_workers = case length(dates) > record["config"]["workers"] do
      :true -> record["config"]["workers"]
      :false ->  length(dates)
    end
    send(progress, {:update_total, length(dates)})
    diagnosis_template = add_group_ages(record["diagnosis_template"], record["group_ages"])
    {:ok, collector} = Collector.start(%{"parent" => self(), "socket_id" => data["socket_id"], "diagnosis_template" => diagnosis_template})
    Process.monitor(collector)
    for index <- 1..n_workers,
    # query["consultation_date"]["$gte"],
    # query["consultation_date"]["$lt"]
      {:ok, pid} = Worker.start(%{"index" => index, "parent" => self(), "query" => Suive.make_query(data["query"], Enum.at(dates, index)), "collector" => collector, "collection" => "attentions", "diagnosis_template" => diagnosis_template}),
      Process.monitor(pid),
      :ok = MWorker.dirty_write(pid, :waiting, date, self()),
      into: %{},
      do: {pid, %{"date" => date, "status" => :waiting}}
    new_state = Map.put(state, "documents", 1) |> Map.put("collector", collector) |> Map.put("total", length(dates))
    LibLogger.save_event(__MODULE__, :count, Map.get(data, "socket_id", :nill), new_state)
    send(self(), {:run, page * 1})
    {:noreply, new_state}

    # send(progress, {:update_total, total})
    # [%{"$match" => query} | _] = data["query"];
    # {:ok, date} = DateTime.now("America/Mexico_City")
    # {:ok, collector} = Collector.start(%{"parent" => self(), "rows" => [], "columns" => name_columns(record["rows"]), "query" => query, "progress" => progress, "socket_id" => data["socket_id"]})
    # Process.monitor(collector)
    # for _index <- 1..get_n_workers(total, round(total / record["config"] ["documents"]), record["config"]["workers"]),
    #   {:ok, pid} = Worker.start(%{"parent" => self(), "rows" => rows_with_out_specials(record["rows"]), "query" => data["query"], "collector" => collector, "collection" => record["collection"]}),
    #   Process.monitor(pid),
    #   :ok = MWorker.dirty_write(pid, :waiting, date, self()),
    #   into: %{},
    #   do: {pid, %{"date" => date, "status" => :waiting}}
    # new_state = Map.put(state, "total", total) |> Map.put("documents", record["config"]["documents"]) |> Map.put("collector", collector)
    # LibLogger.save_event(__MODULE__, :count, Map.get(data, "socket_id", :nill), new_state)
    # send(self(), {:run, page * record["config"]["documents"]})
    # {:noreply, new_state}
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

  def handle_info({:run, _limit}, %{"total" => total, "skip" => skip, "data" => data}=state) when skip >= total do
    LibLogger.save_event(__MODULE__, :run_all, Map.get(data, "socket_id", :nill), state)
    {:noreply, state}
  end

  def handle_info({:run, limit}, %{"total" => total, "skip" => skip, "documents" => documents, "page" => page}=state) when limit <= total do
    Logger.info ["Limit: #{inspect limit}"]
    Logger.info ["total: #{inspect total}"]
    Logger.info ["skip: #{inspect skip}"]
    Logger.info ["documents: #{inspect documents}"]
    Logger.info ["page: #{inspect page}"]
    new_state = case MWorker.next_worker() do
      {:ok, pid} ->
        send(pid, :run)
        #send(self(), {:run, (page + 1) * documents})
        #:ok = MWorker.update_status(pid, {:waiting, :occupied})
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

  def handle_info(:kill, state) do
    kill_processes(["collector", "progress"], state)
    for {_XlsxWorker, pid, _status, _date, _report} <- MWorker.get_workers(self()),
      GenServer.cast(pid, :stop),
      {:atomic, :ok} = MWorker.delete(pid),
      do: []
    GenServer.cast(self(), :stop)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{"collector" => collector}=state) do
    {:atomic, :ok} = MWorker.delete(pid)
    case MWorker.empty_workers(self()) do
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

  def add_group_ages([], ages, group) do
    group
  end

  def add_group_ages([h | t], ages, group) do
    add_group_ages(t, ages, group ++ [Map.put(h, "groupAges", ages)])
  end

  def add_group_ages(%{"group1" => group1, "group2" => group2}, ages) do
    Map.put(%{}, "group1", add_group_ages(group1, ages, [])) |> Map.put("group2", add_group_ages(group2, ages, []))
  end


end