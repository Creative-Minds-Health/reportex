defmodule Xlsx.SrsWeb.Reference.Reference do
  require Logger

  alias Xlsx.Date.Date, as: DateLib

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
  def get_value(item, [_h|_t], "consultation_date", _default_value) do
    case Map.get(item, "consultation_date", :undefined) do
      :undefined -> ""
      date ->
        Calendar.strftime(DateTime.shift_zone!(date, "America/Mexico_City"), "%Y-%m-%d")
    end
  end
  def get_value(item, [_h|_t], "patient|splited_age|years", _default_value) do
    case Map.get(item, "patient", %{}) |> Map.get("splited_age", %{}) |> Map.get("years", :undefined) do
      :undefined -> ""
      age -> Integer.to_string(trunc(age)) <> " AÑOS"
    end
  end
  def get_value(item, [_h|_t], "patient|dh", _default_value) do
    case Map.get(item, "patient", %{}) |> Map.get("dh", :undefined)do
      :undefined -> ""
      dh -> get_dh(dh)
    end
  end
  def get_value(item, [_h|_t], "clue", _default_value) do
    Map.get(item, "clue", "") <> " - " <> Map.get(item, "clue_name", "")
  end
  def get_value(item, [_h|_t], "reference_data", _default_value) do
    hospital_key_clues = Map.get(item, "reference_data", %{}) |> Map.get("hospital_key_clues", "")
    hospital_name = Map.get(item, "reference_data", %{}) |> Map.get("hospital_name", "")
    hospital_key_clues <> " - " <> hospital_name
  end
  def get_value(item, [_h|_t], "diagnosis", _default_value) do
    # diagnosis_key = Map.get(item, "reference_data", %{}) |> Map.get("diagnosis", %{}) |> Map.get("key", "")
    # diagnosis_description = Map.get(item, "reference_data", %{}) |> Map.get("diagnosis", %{}) |> Map.get("description", "")
    # diagnosis_key <> " - " <> diagnosis_description

    # Anteriormente el diagnosis_key se sacaba de: reference_data.diagnosis.key
    # Pero se modifica para que ahora se obtenga de: reference.detail.diagnostic_entry. Relacionado al ticket: T-16042021-002
    Map.get(item, "reference", %{}) |> Map.get("detail", %{}) |> Map.get("diagnostic_entry", "")
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

  def sinba_date(date) do
    DateLib.string_date(date, "-")
  end

  def get_dh(dh_list) when length(dh_list) <= 0 do
    ""
  end
  def get_dh(dh_list) when length(dh_list) >= 1 do
    case for item <- dh_list, item["key"] === 1 and item["affiliate_program"] === 1, do: item do
      [principal_entitled | _] ->
        Map.get(principal_entitled, "insurance_policy", "")
      _->
        ""
    end
  end
end
