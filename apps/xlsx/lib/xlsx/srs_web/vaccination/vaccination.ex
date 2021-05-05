defmodule Xlsx.SrsWeb.Vaccination.Vaccination do
  require Logger

  alias Xlsx.Date.Date, as: DateLib

  def get_params(state) do
    [%{"$match" => query} | _] = Map.get(state, "data") |> Map.get("query")
    %{
      "user" => Map.get(query, "assistance.current.user.email", "N/A"),
      "appointment_date" => Map.get(query, "date_date", "N/A"),
      "assistance_date" => Map.get(query, "assistance.current.date", %{}) |> Map.get("$gte", "N/A"),
      "clues" => Map.get(query, "clues.key", "N/A")
    }
  end

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

  def get_value(item, [_h|_t], "current_date", default_value) do
    DateLib.string_date( Map.get(item, "current_date") |> DateTime.shift_zone!("America/Mexico_City"), "/", "DD/MM/YYYY HH:MM")
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

  def get_diagnosis(_diagnosis, list, 3) do
    list
  end
  def get_diagnosis([h|t], list, count_diagnosis) do
    new_list = case Map.get(h, "first_time", :undefined) do
      0 -> list ++ ["Subsecuente"]
      1 -> list ++ ["1ra vez"]
      _ -> list ++ [""]
    end

    new_desc = case {Map.get(h, "key_diagnosis", :undefined), Map.get(h, "description", :undefined)} do
      {:undefined, :undefined} -> new_list ++ [""]
      {key, description} ->
        new_list ++ [key <> " - " <> description]
    end

    get_diagnosis(t, new_desc, count_diagnosis + 1)
  end

  def get_dh(dh_list) when length(dh_list) <= 0 do
    ""
  end
  def get_dh(dh_list) when length(dh_list) >= 1 do
    case for item <- dh_list, item["key"] === 1, do: item do
      [principal_entitled | _] ->
        case Map.get(principal_entitled, "affiliate_program", :undefined) do
          1 -> "X"
          _ -> ""
        end
      _->
        ""
    end
  end
end
