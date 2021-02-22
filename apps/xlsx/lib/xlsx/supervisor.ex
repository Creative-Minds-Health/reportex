defmodule Xlsx.Supervisor do
  use Supervisor
  require Logger

  alias Xlsx.Mongodb.Mongodb, as: Mongodb

  # API
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  # Callbacks
  @impl true
  def init(args) do
    IO.puts "args: #{inspect args}"
    node = Application.get_env(:xlsx, :node)
    {:ok, srs_gcs} = Application.get_env(:xlsx, :srs_gcs) |> Poison.decode()
    :ok = Application.put_env(:xlsx, :srs_gcs, Map.put(srs_gcs, "key_file_name", :filename.join(File.cwd!(), Map.get(srs_gcs, "key_file_name"))))
    IO.puts "mode: #{inspect node}"
    children = case node do
      :master ->
        [
          priv_child_spec({Socket, Xlsx.Socket, %{}}),
          priv_child_spec({Master, Xlsx.Cluster.Master, %{}})
        ]
      _->
        [
          priv_child_spec({Slave, Xlsx.Cluster.Slave, %{}})
          # priv_child_spec({Mongo, Mongo, Mongodb.config(mongodb)}),
          # priv_child_spec({NodeJS, NodeJS, [path: js_path, pool_size: 10]})
        ]
    end
    Supervisor.init(children, strategy: :one_for_one)
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
