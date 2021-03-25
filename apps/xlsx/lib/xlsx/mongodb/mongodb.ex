defmodule Xlsx.Mongodb.Mongodb do
  require Logger

  def config(mongodb) do
    shard_config = case mongodb["shard"] do
      :true ->
        [
          ssl: true,
          ssl_opts: [
            ciphers: ['AES256-GCM-SHA384'],
            versions: [:"tlsv1.2"]
          ],
          read_preference: Mongo.ReadPreference.slave_ok(%{mode: :secondary_preferred}),
          slave_ok: true
        ]
      _-> []
    end
    [
      name: :mongo, database: mongodb["db"],
      pool_size: mongodb["pool_size"],
      url: mongodb["url"],
      queue_target: 5_000,
      queue_interval: 10_000
    ] ++ shard_config;
  end

  def count_query(data_decode, collection) do
    [%{"$match" => query} | _] = data_decode["query"]
    {:ok, total} = Mongo.count(:mongo, collection, query)
    total
  end

  def count_query_aggregate(data_decode, collection) do
    count = Mongo.aggregate(:mongo, collection, data_decode["query"])
    |> Stream.map(&(
      &1["total"]
    ))
    |> Enum.to_list()

    case count do
      [] -> 0
      [total | _] -> total
    end
  end
end
