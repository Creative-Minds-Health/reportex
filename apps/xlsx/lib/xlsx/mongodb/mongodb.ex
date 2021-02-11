defmodule Xlsx.Mongodb.Mongodb do
  require Logger

  def count_query(data_decode, collection) do
    [%{"$match" => query} | _] = data_decode["query"]
    {:ok, total} = Mongo.count(:mongo, collection, query)
    total
  end
end
