defmodule Xlsx.Socket do
  use GenServer
  require Logger

  # API
  def start_link(state) do
    GenServer.start_link(__MODULE__, Map.put(state, :workers, %{}), name: __MODULE__)
  end
  def get_document do
    cursor = Mongo.find(:mongo, "egresses", %{"_id" => "MNSSA016492-001159"})
    # cursor = Mongo.find(:mongo, "users", %{})
    rows = cursor
      |>
        Stream.map(&([
          &1["patient"]["nationality"]["name"],
        ]))
      |> Enum.to_list()
    IO.puts "#{inspect rows}"
  end


  # Callbacks
  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Logger.info "GenServer is running..."
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    Logger.info "UNKNOWN INFO MESSAGE"
    {:noreply, state}
  end
end
