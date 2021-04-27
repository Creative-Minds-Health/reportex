defmodule Xlsx.SrsWeb.Consult.Consult do
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

  def get_value(item, [_h|_t], "patient|address|street", default_value) do
    street = Map.get(item, "patient", %{}) |> Map.get("address", %{}) |> Map.get("street", default_value)
    number = Map.get(item, "patient", %{}) |> Map.get("address", %{}) |> Map.get("number", default_value)
    street <> " " <> number
  end
  def get_value(item, [_h|_t], "affiliate_program", default_value) do
    case Map.get(item, "patient", %{}) |> Map.get("dh", :undefined)do
      :undefined -> default_value
      dh -> get_dh(dh)
    end
  end
  def get_value(item, [_h|_t], "patient|migrant|key", default_value) do
    case Map.get(item, "patient", %{}) |> Map.get("migrant", %{}) |> Map.get("key", :undefined) do
      1 -> "X"
      _ -> default_value
    end
  end
  def get_value(item, [_h|_t], "patient|indigenous|key", default_value) do
    case Map.get(item, "patient", %{}) |> Map.get("indigenous", %{}) |> Map.get("key", :undefined) do
      1 -> "X"
      _ -> default_value
    end
  end
  def get_value(item, [_h|_t], "patient|disability", default_value) do
    case Map.get(item, "patient", %{}) |> Map.get("disability", :undefined) do
      true -> "X"
      _ -> default_value
    end
  end
  def get_value(item, [_h|_t], "diagnosis", _default_value) do
    diagnosis = Map.get(item, "diagnosis", []);
    new_diagnosis = case length(diagnosis) do
      0 ->
        [%{}, %{}, %{}]
      1 ->
        diagnosis ++ [%{}, %{}]
      2 ->
        diagnosis ++ [%{}]
      _ -> diagnosis

    end
    {:multi, get_diagnosis(new_diagnosis, [], 0)}
  end
  def get_value(item, [_h|_t], "reference", default_value) do
    case Map.get(item, "reference_data", %{}) |> Map.get("reference_contrareference", %{}) |> Map.get("key", :undefined) do
      1 -> "X"
      _ -> default_value
    end
  end
  def get_value(item, [_h|_t], "contrarreference", default_value) do
    case Map.get(item, "reference_data", %{}) |> Map.get("reference_contrareference", %{}) |> Map.get("key", :undefined) do
      2 -> "X"
      _ -> default_value
    end
  end

  def get_value(item, [_h|_t], "reference_clue_name", default_value) do
    case Map.get(item, "unitLevel", :undefined) do
      "N2" ->
        Map.get(item, "reference", %{}) |> Map.get("unit_clue_origin", %{}) |> Map.get("name", default_value)
      _ ->
        Map.get(item, "reference_data", %{}) |> Map.get("hospital_name", default_value)
    end
  end

  def get_value(item, [_h|_t], "_id", default_value) do
    case Map.get(item, "unitLevel", :undefined) do
      "N2" ->
        "https://michoacan.efimed.care/#/app/consultas/detalle/N2/" <> Map.get(item, "_id", default_value)
      _ ->
        "https://michoacan.efimed.care/#/app/consultas/detalle/N1/" <> Map.get(item, "_id", default_value)
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
