defmodule Xlsx.Ors.Product.BilledConsumption.Parser do
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
  def get_value(item, [_h|_t], "billed|folio", _default_value) do
    get_folios(Map.get(item, "billed", []), {:init, ""})
  end
  def get_value(item, [_h|_t], "surgery_dateTime", _default_value) do
    Calendar.strftime(DateTime.shift_zone!(Map.get(item, "surgery_dateTime"), "America/Mexico_City"), "%Y-%m-%d %H:%M")
  end
  def get_value(item, [_h|_t], "remissions_related", _default_value) do
    get_folios(Map.get(item, "remissions_related", []), {:init, ""})
  end
  def get_value(item, [_h|_t], "assign", _default_value) do
    case Map.get(item, "assign") do
      "PROVIDER" -> "PROVEEDOR"
      "LOCAL" -> "CONSIGNA"
      "WAREHOUSE" -> "ALMACÉN"
      _-> "N/A"
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

  defp get_folios([], {_, acc}) do
    acc
  end
  defp get_folios([h|t],  {:init, acc}) do
    get_folios(t, {:nil, Map.get(h, "folio")})
  end
  defp get_folios([h|t],  {_, acc}) do
    get_folios(t, {:nil, acc <> "," <> Map.get(h, "folio")})
  end

end
