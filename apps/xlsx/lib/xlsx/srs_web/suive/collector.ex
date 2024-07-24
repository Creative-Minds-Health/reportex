defmodule Xlsx.SrsWeb.Suive.Collector do
  use GenServer
  require Logger

  alias Xlsx.SrsWeb.Suive.Concat, as: Concat
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
    {:ok, state}
  end

  @impl true
  def handle_call({:concat, data}, _from, %{"diagnosis_template" => diagnosis_template, "progress" => progress}=state) do
    send(progress, :documents)
    {:reply, :ok, Map.put(state, "diagnosis_template", Concat.concat_data(data, diagnosis_template, Map.keys(diagnosis_template)))}
  end

  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:generate, %{"diagnosis_template" => diagnosis_template, "progress" => progress, "params" => params, "socket_id" => socket_id}=state) do
    send(progress, {:update_status, :writing})
    LibLogger.save_event(__MODULE__, :generating_xlsx, socket_id, %{})
    python_path = :filename.join(:code.priv_dir(:xlsx), "lib/python/srs_web/consult/first_level") |> String.to_charlist()
    # {:ok, pid} = :python.start([{:python_path, python_path}, {:python, 'python2'}])
    # {:ok, pid} = :python.start([{:python_path, python_path}, {:python, 'python3.7'}])
    {:ok, pid} = :python.start([{:python_path, python_path}, {:python, 'python'}])
    file_name = DateLib.file_name_date("-") <> ".xlsx"
    file_path = :filename.join(:code.priv_dir(:xlsx), "assets/report/")
    json = Poison.encode!(%{
      "consults" => diagnosis_template,
      "data" => %{
        "pathTemplate" => :filename.join(:code.priv_dir(:xlsx), "lib/python/srs_web/consult/first_level/SUIVE-400.xlsx"),
        "logo" => :filename.join(:code.priv_dir(:xlsx), "assets/logoSuive.png"),
        "params" => Map.put(get_params(params), "institution_name", "SECRETARÍA DE SALUD"),
        "path" => :filename.join(file_path, file_name)
      }
    })
    response = :python.call(pid, :rep, :initrep, [json])
    # case Map.get(response, "success", :false) do
    case success_response(response) do
      :true -> send(progress, {:done, file_path, file_name})
      _-> Logger.error ["paso mal"]
    end
    {:noreply, state}
  end
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, :normal}, state) do
    {:noreply, state}
  end
  def handle_info(msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE #{inspect msg}"
    {:noreply, state}
  end

  @impl true
  def terminate(:normal, _state) do
    :ok
  end
  def terminate(_reason, %{"parent" => parent}=_state) do
    send(parent, :kill)
    :ok
  end

  def get_date_now(:undefined, separator) do
    today = DateTime.utc_now
    [today.year, today.month, today.day]
    Enum.join [get_number(today.day), get_number(today.month), today.year], separator
  end

  def get_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end

  def get_number(number) do
    number;
  end

  def get_params(params) do
    [state | _] = get_state(Map.get(params, "state", :nil))
    [jurisdiction | _] = get_jurisdiction(state["_id"], Map.get(params, "jurisdiction", :nil))
    [clue | _] = get_clue(Map.get(params, "clue", :nil))
    response = %{"state_id" => state["_id"], "state" => state["name"], "jurisdiction_id" => jurisdiction["key"], "jurisdiction" => jurisdiction["name"], "clueName" => clue["name"], "institution_name" => clue["institution_name"], "municipality" => clue["municipality_name"], "municipality_key" => clue["municipality_key"], "clue" => params["clue"], "startDate" => get_dates(params["startDate"]), "endDate" => get_dates(params["endDate"])}
    # case clue["municipality_key"] != "" do
    #   true ->
    #     [locality | _] = get_locality(clue["municipality_key"])
    #     Map.put(response, "location", locality["name"])
    #   _ -> response
    # end
    case clue["locality_name"] != "" do
      true ->
        Map.put(response, "location", clue["locality_name"])
      _ -> response
    end
  end

  def get_state(state) do
    Mongo.find(:mongo, "states", %{"_id" => state}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_jurisdiction(_state_id, :nil) do
    [%{"_id" => "", "name" => ""}]
  end
  def get_jurisdiction(state_id, key) do
    Mongo.find(:mongo, "jurisdictions", %{"state_id" => state_id, "key" => key}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_clue(:nil) do
    [%{"name" => "", "institution_name" => "", "municipality_name" => "", "municipality_key" => ""}]
  end
  def get_clue(clue) do
    Mongo.find(:mongo, "cies", %{"_id" => clue}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_locality(municipality) do
    Mongo.find(:mongo, "localities", %{"municipality_key" => municipality}, [timeout: 60_000]) |> Enum.to_list()
  end

  def get_dates(date) do
    [month, day, year] = String.split(date, "/")
    %{"day" => day, "month" => month, "year" => year}
  end

  def success_response(response) do
    success_response(response, ["success", 'success'])
  end

  def success_response(_response, []) do
    :nil
  end
  def success_response(response, [h|t]) do
    success_response(response, t, Map.get(response, h, :nil))
  end

  def success_response(response, fields, :nil) do
    success_response(response, fields)
  end
  def success_response(_response, _fields, value) do
    value
  end

end
