defmodule Xlsx.Decode.Mongodb do
  require Logger

  def decode([]) do
    []
  end
  def decode([map|t]) do
    [priv_decode({map, %{}}, Map.keys(map)) | decode(t)]
  end
  def decode(map) when is_map(map) do
    Logger.info ["Entra ajlkajklasjklajkl #{inspect map}"]
    priv_decode({map, %{}}, Map.keys(map))
  end




  defp priv_decode({map, acc}, []) do
    acc
  end
  defp priv_decode({map, acc}, [key|t]) do
    value = priv_decode({map, %{}}, key, map[key])
    priv_decode({map, Map.put(acc, key, value) }, t)
  end
  defp priv_decode({map, acc}, "_id", value) when is_struct(value) do
    {:ok, id} = BSON.ObjectId.encode(map["_id"])
    id
  end
  defp priv_decode({map, acc}, key, value) when is_map(value) do
    new_value = case Map.keys(value) do
      [:__struct__, :calendar, :day, :hour, :microsecond, :minute, :month, :second, :std_offset, :time_zone, :utc_offset, :year, :zone_abbr] ->
        value
      _-> priv_decode({value, %{}}, Map.keys(value))
    end
    new_value
  end
  defp priv_decode({map, acc}, key, []) do
    []
  end
  defp priv_decode({map, acc}, key, value) when is_list(value) do
    [h|t] = value
    case is_map(h) do
      :true -> decode(value)
      _-> value
    end
  end

  defp priv_decode({map, acc}, key, value) do
    value
  end
end
