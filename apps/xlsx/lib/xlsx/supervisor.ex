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
    js_path = :filename.join(:code.priv_dir(:xlsx), "lib/js")
    children = [
      %{
        id: Socket,
        start: {Xlsx.Socket, :start_link, [%{}]},
        restart: :permanent,
        shutdown: 2_000,
        type: :worker,
        modules: [Xlsx.Socket]
      },
      %{
        id: Mongo,
        start: {Mongo, :start_link, [[
          name: :mongo, database: Application.get_env(:xlsx, :mongodb_database),
          pool_size: Application.get_env(:xlsx, :mongodb_pool_size),
          url: Application.get_env(:xlsx, :mongodb_url),
          # ssl: true,
          # ssl_opts: [
          #   ciphers: ['AES256-GCM-SHA384'],
          #   versions: [:"tlsv1.2"]
          # ],
          queue_target: 5_000,
          queue_interval: 10_000,
          # read_preference: Mongo.ReadPreference.slave_ok(%{mode: :secondary_preferred}),
          # slave_ok: true
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
    Supervisor.init(children, strategy: :one_for_one)
  end
  # Internal
end
