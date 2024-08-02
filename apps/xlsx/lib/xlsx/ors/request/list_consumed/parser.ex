defmodule Xlsx.Ors.Request.ListConsumed.Parser do
  require Logger

  alias Xlsx.Date.Date, as: DateLib

  def file_name (query) do
    consultation_date(query, "$gte") <> "-" <> consultation_date(query, "$lte")
  end
  defp consultation_date(query, operator) do
    DateLib.string_date(
      Map.get(query, "consultation_date", %{})
        |> Map.get(operator, :nil)
        |> DateTime.shift_zone!("America/Mexico_City"),
      "",
      "MMDDYYYY"
    )
  end

  def iterate_fields(_item, []) do
    []
  end

  def iterate_fields(item, [h|t]) do
    case get_value(item, h["field"] |> String.split("|"), h["field"], h["default_value"]) do
      {:multi, value} ->
        value ++ iterate_fields(item, t);
      value ->
        [value | iterate_fields(item, t)]
    end
  end

  def get_value(item, [], _field, _default_value) do
    item
  end
  def get_value(item, [_h|_t], _, "ignore") do

  end
  def get_value(item, [_h|_t], "products", _default_value) do
    value = Map.get(item, "products", %{})
    {:products, value}
  end
  def get_value(item, [_h|_t], "last_status.modified_date", _default_value) do
    Calendar.strftime(Map.get(item, "last_status") |> Map.get("modified_date"),"%d/%m/%Y %H:%M:%S")
  end
  def get_value(item, [_h|_t], "last_status|name", _default_value) do
    value = Map.get(item, "last_status", %{}) |> Map.get("name", :undefined)
    case value do
      "OPEN" -> "Abierta"
      "APPROVED" -> "Aprobada"
      "MANAGEMENT" -> "En gestión"
      "DELIVERED" -> "Entregada"
      "INVOICE" -> "Por facturar"
      "BILLED" -> "Facturada"
      "CHARGED" -> "Por cobrar"
      "PAID" -> "Pagada"
      "WITHOUT" -> "Sin consumo"
      "CANCELED" -> "Cancelada"
      _ -> ""
    end
  end

  def get_value(item, [_h|_t], "no_procedures", _default_value) do
    a = Map.get(item, "procedures", :nil)
    Logger.info ["a: #{inspect a}"]
    case Map.get(item, "procedures", :nil) do
      :nil ->
        ""
      [h] -> Map.get(h, "position", "")
      _ -> ""
    end
  end
  def get_value(item, [_h|_t], "description_procedures", _default_value) do
    a = Map.get(item, "procedures", :nil)
    Logger.info ["a: #{inspect a}"]
    case Map.get(item, "procedures", :nil) do
      :nil ->
        ""
      [h] -> Map.get(h, "description", "")
      _ -> ""
    end
  end

  def get_value(item, [_h|_t], "surgery_dateTime", _default_value) do
    Calendar.strftime(Map.get(item, "surgery_dateTime"),"%d/%m/%Y %H:%M:%S")
  end
  def get_value(item, [_h|_t], "reception_dateTime", _default_value) do
    Calendar.strftime(Map.get(item, "reception_dateTime"),"%d/%m/%Y %H:%M:%S")
  end
  def get_value(item, [_h|_t], "creation_date", _default_value) do
    Calendar.strftime(Map.get(item, "creation_date"),"%d/%m/%Y %H:%M:%S")
  end
  def get_value(item, [_h|_t], "_id|origin|name", _default_value) do
    origin = Map.get(item, "_id") |> Map.get("origin") |> Map.get("_id")
    {marfer_id, origin_id} = case is_bitstring(origin) do
      true ->
        {"574ba97afb843dcc7b233a62", origin}
      _ -> {<<87, 75, 169, 122, 251, 132, 61, 204, 123, 35, 58, 98>>, origin.value}
    end
    case {marfer_id, origin_id} do
      {same, same} -> "ALMACÉN MARFER"
      {_, _} -> Map.get(item, "_id") |> Map.get("origin") |> Map.get("name")
    end
  end
  def get_value(item, [_h|_t], "_id|returned", _default_value) do
    value = Map.get(item, "_id") |> Map.get("returned", :nil)
    case value do
      :true -> "SI"
      _-> ""
    end
  end

  def get_value(item, [h|t], field, default_value) do
    case Map.get(item, h, :undefined) do
      :undefined -> default_value
      value ->
        case value do
          :nil -> default_value
          _ -> get_value(value, t, field, default_value)
        end
    end
  end
end
