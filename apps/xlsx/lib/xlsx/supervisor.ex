defmodule Xlsx.Supervisor do
  use Supervisor
  require Logger

  # API
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  # Callbacks
  @impl true
  def init(args) do
    IO.puts "args: #{inspect args}"
    node = Application.get_env(:xlsx, :node)
    {:ok, mongodb} = Application.get_env(:xlsx, :mongodb) |> Poison.decode()
    {:ok, srs_gcs} = Application.get_env(:xlsx, :srs_gcs) |> Poison.decode()
    :ok = Application.put_env(:xlsx, :srs_gcs, Map.put(srs_gcs, "key_file_name", :filename.join(File.cwd!(), Map.get(srs_gcs, "key_file_name"))))
    js_path = :filename.join(:code.priv_dir(:xlsx), "lib/js")
    IO.puts "mode: #{inspect node}"


    children = case node do
      :master ->
        [%{
          id: Socket,
          start: {Xlsx.Socket, :start_link, [%{}]},
          restart: :permanent,
          shutdown: 2_000,
          type: :worker,
          modules: [Xlsx.Socket]
        },
        %{
          id: Register,
          start: {Xlsx.Register, :start_link, [%{}]},
          restart: :permanent,
          shutdown: 2_000,
          type: :worker,
          modules: [Xlsx.Register]
        }]
      _->
        [
          %{
            id: Listener,
            start: {Xlsx.Listener, :start_link, [%{}]},
            restart: :permanent,
            shutdown: 2_000,
            type: :worker,
            modules: [Xlsx.Listener]
          },
          %{
            id: Mongo,
            start: {Mongo, :start_link, [[
              name: :mongo, database: mongodb["db"],
              pool_size: mongodb["pool_size"],
              url: mongodb["url"],
              ssl: true,
              ssl_opts: [
                ciphers: ['AES256-GCM-SHA384'],
                versions: [:"tlsv1.2"]
              ],
              queue_target: 5_000,
              queue_interval: 10_000,
              read_preference: Mongo.ReadPreference.slave_ok(%{mode: :secondary_preferred}),
              slave_ok: true
            ]]},
            restart: :permanent,
            shutdown: 2_000,
            type: :worker,
            modules: [Mongo]
          },
          %{
            id: NodeJS,
            start: {NodeJS, :start_link, [[path: js_path, pool_size: 10]]},
            restart: :permanent,
            shutdown: 2_000,
            type: :worker,
            modules: [NodeJS]
          }
        ]
    end

    Supervisor.init(children, strategy: :one_for_one)
  end
  # Internal
end
