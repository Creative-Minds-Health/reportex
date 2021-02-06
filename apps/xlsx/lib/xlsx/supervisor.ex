defmodule Xlsx.Supervisor do
  use Supervisor

  # API
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  # Callbacks
  @impl true
  def init(args) do
    IO.puts "args: #{inspect args}"
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
          timeout: 30_000,
          ssl: true,
          ssl_opts: [
            ciphers: ['AES256-GCM-SHA384'],
            versions: [:"tlsv1.2"]
]
          ]]},
        restart: :permanent,
        shutdown: 2_000,
        type: :worker,
        modules: [Mongo]
      }
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  # Internal
end
