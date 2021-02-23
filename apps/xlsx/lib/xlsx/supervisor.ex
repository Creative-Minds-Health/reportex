defmodule Xlsx.Supervisor do
  use Supervisor
  require Logger

  alias Xlsx.Mongodb.Mongodb, as: Mongodb
  alias Xlsx.Mnesia.Node, as: MNode

  # API
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  # Callbacks
  @impl true
  def init(_args) do

    node = Application.get_env(:xlsx, :node)
    report_config = Application.get_env(:xlsx, :report)
    {:ok, srs_gcs} = Application.get_env(:xlsx, :srs_gcs) |> Poison.decode()
    :ok = Application.put_env(:xlsx, :srs_gcs, Map.put(srs_gcs, "key_file_name", :filename.join(File.cwd!(), Map.get(srs_gcs, "key_file_name"))))

    children = case node do
      :master ->
        MNode.save_node(Node.self, report_config[:size], 0, DateTime.now!("America/Mexico_City") |> DateTime.to_unix())
        [
          priv_child_spec({Socket, Xlsx.Socket, %{}}),
          priv_child_spec({Master, Xlsx.Cluster.Master, %{}})
        ]
        _->
          []
    end

    {:ok, mongodb} = Application.get_env(:xlsx, :mongodb) |> Poison.decode()
    js_path = :filename.join(:code.priv_dir(:xlsx), "lib/js")

    default = [
      priv_child_spec({Mongo, Mongo, Mongodb.config(mongodb)}),
      priv_child_spec({NodeJS, NodeJS, [path: js_path, pool_size: 10]}),
      priv_child_spec({Listener, Xlsx.Cluster.Listener, %{}})
    ]

    Supervisor.init(children ++ default, strategy: :one_for_one)
  end

  def start_children(list) do
    start_child(list)
  end

  # Internal
  defp start_child([]) do
    :ok
  end
  defp start_child([:mongodb|t]) do
    {:ok, mongodb} = Application.get_env(:xlsx, :mongodb) |> Poison.decode()
    spec = priv_child_spec({Mongo, Mongo, Mongodb.config(mongodb)})
    {:ok, _} = Supervisor.start_child(__MODULE__, spec)
    Logger.info ["Inicia child de mongodb"]
    start_child(t)
  end
  defp start_child([:nodejs|t]) do
    js_path = :filename.join(:code.priv_dir(:xlsx), "lib/js")
    spec = priv_child_spec({NodeJS, NodeJS, [path: js_path, pool_size: 10]})
    {:ok, _} = Supervisor.start_child(__MODULE__, spec)
    Logger.info ["Inicia child de nodejs"]
    start_child(t)
  end
  defp priv_child_spec({id, module, args}) do
    %{
      id: id,
      start: {module, :start_link, [args]},
      restart: :permanent,
      shutdown: 2_000,
      type: :worker,
      modules: [module]
    }
  end
end
