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
      }
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  # Internal
end
