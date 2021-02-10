defmodule Xlsx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Xlsx.Worker.start_link(arg)
      # {Xlsx.Worker, arg}
      Xlsx.Supervisor
    ]
    :stopped = :mnesia.stop()
    :ok = :mnesia.delete_schema([node()])
    :mnesia.create_schema([node()])
    :ok = :mnesia.start()
    :ok = Xlsx.Mnesia.Worker.init()
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Xlsx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
