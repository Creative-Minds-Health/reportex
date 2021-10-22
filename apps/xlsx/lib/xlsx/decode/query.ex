defmodule Xlsx.Decode.Query do
  require Logger

  def decode(:nil) do
    %{}
  end
  def decode([]) do
    []
  end
  def decode([map|t]) when is_integer(map)  do
    [map | decode(t)]
  end
  def decode([map|t]) when is_bitstring(map)  do

    value = case String.match?(map, ~r/([0-9]{4}[-][0-9]{2}[-][0-9]{2}[T][0-9]{2}[:][0-9]{2}[:][0-9]{2}[.][0-9]{3}[Z])/) do
      true -> to_date(map)
      _-> map
    end
    # [to_date(map) | decode(t)]
    [value | decode(t)]
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
  defp priv_decode({map, _acc}, "destination._id", value) when is_bitstring(value) do
    {_, idbin} = Base.decode16(map["destination._id"], case: :mixed)
    %BSON.ObjectId{value: idbin}
  end
  defp priv_decode({map, _acc}, "origin._id", value) when is_bitstring(value) do
    {_, idbin} = Base.decode16(map["origin._id"], case: :mixed)
    %BSON.ObjectId{value: idbin}
  end
  defp priv_decode({_map, _acc}, "$gte", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({_map, _acc}, "$lte", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({_map, _acc}, "$gt", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({_map, _acc}, "$lt", value) when is_bitstring(value) do
    to_date(value)
  end
  defp priv_decode({_map, _acc}, "$in", value) do
    Enum.map(value, fn item ->
      case (is_bitstring(item) && String.length(item) === 24) do
        true ->
          {_, idbin} = Base.decode16(item, case: :mixed)
          %BSON.ObjectId{value: idbin}
        _-> item
      end
    end)
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
  # Se agrega match para hacer una expresión regular en un string y verificar si es un string de fecha.
  # "2021-05-04T05:00:00.000Z"
  defp priv_decode({_map, _acc}, _key, value) when is_bitstring(value) do
    case String.match?(value, ~r/([0-9]{4}[-][0-9]{2}[-][0-9]{2}[T][0-9]{2}[:][0-9]{2}[:][0-9]{2}[.][0-9]{3}[Z])/) do
      true -> to_date(value)
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
