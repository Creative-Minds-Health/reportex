defmodule Xlsx.SrsWeb.Egress.Egress do
  require Logger

  alias Xlsx.SrsWeb.Egress.ParserEgress, as: ParserEgress
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

  def get_value(item, [_h|_t], "patient|nationality|key", default_value) do
    ParserEgress.nationality(Map.get(Map.get(item, "patient", %{}), "is_abroad", 0), Map.get(item, "patient", %{}) |> Map.get("nationality", %{}) |> Map.get("key", ""), default_value)

  end

  def get_value(item, [_h|_t], "patient|splited_age", default_value) do
    splited_age = Map.get(item, "patient", %{}) |> Map.get("splited_age", %{})
    {:multi, ParserEgress.age(Map.get(splited_age, "years", 0), Map.get(splited_age, "months", 0), Map.get(splited_age, "days", 0), default_value)}
  end

  def get_value(item, [_h|_t], "patient|dh", default_value) do
    {:multi, ParserEgress.dh(Map.get(item, "patient", %{}) |> Map.get("dh", []), default_value)}
  end

  def get_value(item, [_h|_t], "stay|origin|unit_clue|key", default_value) do
    ParserEgress.clues(Map.get(item, "stay", %{}) |> Map.get("origin", %{}) |> Map.get("unit_clue", %{}) |> Map.get("key", :undefined), Map.get(item, "clue", :undefined), default_value)
  end

  def get_value(item, [_h|_t], "comorbidity|comorbidities", _default_value) do
    {:multi, ParserEgress.comorbidities(Map.get(item, "comorbidity", :undefined), Map.get(item, "comorbidity", %{}) |> Map.get("comorbidities", []))}
  end

  def get_value(item, [_h|_t], "procedures", _default_value) do
    {:multi, ParserEgress.procedures(Map.get(item, "procedures", []))}
  end

  def get_value(item, [_h|_t], "product", _default_value) do
    {:multi, ParserEgress.product(Map.get(item, "product", []))}
  end

  def get_value(item, [_h|_t], "stay|additional_service", _default_value) do
    {:multi, ParserEgress.additional_service(Map.get(item, "stay", %{}) |> Map.get("additional_service", []))}
  end

  def get_value(item, [_h|_t], "patient|curp", _default_value) do
    #{:ok, patient} = Poison.encode(Xlsx.Decode.Mongodb.decode(item["patient"]))
    #{:ok, stay} = Poison.encode(Xlsx.Decode.Mongodb.decode(item["stay"]))
    #{:ok, response} = NodeJS.call({"modules/sinba/bulk-load/egress/egress.helper.js", :validatePatientCurp}, [patient, stay])
    item["patient"]["curp"]
  end

  def get_value(item, [_h|_t], "stay|admission_date", _default_value) do
    case Map.get(item, "stay", %{}) |> Map.get("admission_date", :undefined) do
      :undefined -> ""
      date ->
        sinba_date(date)
    end
  end
  def get_value(item, [_h|_t], "stay|exit_date", _default_value) do
    case Map.get(item, "stay", %{}) |> Map.get("exit_date", :undefined) do
      :undefined -> ""
      date ->
        sinba_date(date)
    end
  end

  def get_value(item, [_h|_t], "affections|main_diagnosis|key_diagnosis", default_value) do
    case Map.get(item, "affections", %{}) |> Map.get("main_diagnosis", %{}) |> Map.get("key_diagnosis", "") do
      "" -> default_value
      key_diagnosis ->
        String.replace(key_diagnosis, ".", "", global: true)
    end
  end

  def get_value(item, [_h|_t], "comorbidity|diagnosis|key_diagnosis", default_value) do
    case Map.get(item, "comorbidity", %{}) |> Map.get("diagnosis", %{}) |> Map.get("key_diagnosis", "") do
      "" -> default_value
      key_diagnosis ->
        String.replace(key_diagnosis, ".", "", global: true)
    end
  end

  def get_value(item, [_h|_t], "comorbidity|main_condition_reselected|key", default_value) do
    case Map.get(item, "comorbidity", %{}) |> Map.get("main_condition_reselected", %{}) |> Map.get("key", "") do
      "" -> default_value
      key ->
        case key do
          :nil -> ""
          _ -> String.replace(key, ".", "", global: true)
        end
    end
  end

  def get_value(item, [_h|_t], "comorbidity|external_cause|key", default_value) do
    case Map.get(item, "comorbidity", %{}) |> Map.get("external_cause", %{}) |> Map.get("key", "") do
      "" -> default_value
      key_diagnosis ->
        case key_diagnosis do
          :nil -> ""
          _ -> String.replace(key_diagnosis, ".", "", global: true)
        end
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

  def sinba_date(date) do
    DateLib.string_date(date, "/")
    #{:ok, json} = Poison.encode(%{"date" => DateTime.to_string(date)})
    #{:ok, response} = NodeJS.call({"modules/sinba/bulk-load/bulk-load.helper.js", :sinbaDate}, [json])
    # response["date"]
    # DateTime.to_string(date)
  end
end
