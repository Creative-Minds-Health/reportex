defmodule Xlsx.Decode.Query do
  require Logger

  def decode(:nil) do
    %{}
  end
  def decode([]) do
    []
  end
  def decode([map|t]) do
    [priv_decode({map, %{}}, Map.keys(map)) | decode(t)]
  end
  def decode(map) when is_map(map) do
    priv_decode({map, %{}}, Map.keys(map))
  end




  defp priv_decode({_map, acc}, []) do
    acc
  end
  defp priv_decode({map, acc}, [key|t]) do
    value = priv_decode({map, %{}}, key, map[key])
    priv_decode({map, Map.put(acc, key, value) }, t)
  end
  defp priv_decode({map, _acc}, "_id", value) when is_struct(value) do
    {:ok, id} = BSON.ObjectId.encode(map["_id"])
    id
  end
  defp priv_decode({map, _acc}, "$gte", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({map, _acc}, "$lte", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({map, _acc}, "$gt", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({map, _acc}, "$lt", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({_map, _acc}, _key, value) when is_map(value) do
    new_value = case Map.keys(value) do
      [:__struct__, :calendar, :day, :hour, :microsecond, :minute, :month, :second, :std_offset, :time_zone, :utc_offset, :year, :zone_abbr] ->
        value
      _-> priv_decode({value, %{}}, Map.keys(value))
    end
    new_value
  end
  defp priv_decode({_map, _acc}, _key, []) do
    []
  end
  defp priv_decode({_map, _acc}, _key, value) when is_list(value) do
    [h|_t] = value
    case is_map(h) do
      :true -> decode(value)
      _-> value
    end
  end

  defp priv_decode({_map, _acc}, _key, value) do
    value
  end

  def to_date(string_date) do
    {:ok, date, _} = DateTime.from_iso8601(string_date)
    date
  end

end
