defmodule Xlsx.SrsWeb.ParserA do
  require Logger

  def age(years, _months, _days, _default_value) when (years >= 1 and years <= 120) do
    [years, 5]
  end
  def age(_years, months, _days, _default_value) when (months >= 1 and months <= 11) do
    [months, 4]
  end
  def age(_years, _months, days, _default_value) when (days >= 1 and days <= 29) do
    [days, 3]
  end
  def age(_years, _months, _days, default_value) do
    [default_value, 9]
  end

  def nationality(is_abroad, nationality_key, _default_value) when is_abroad === 1 do
    nationality_key
  end
  def nationality(_is_abroad, _nationality_key, default_value) do
    default_value
  end

  def dh(dh_list, default_value) when length(dh_list) <= 0 do
    [default_value, "-1", "", ""]
  end
  def dh(dh_list, default_value) when length(dh_list) === 1 do
    [first | _] = dh_list
    get_dh(first, default_value)
  end
  def dh(dh_list, default_value) when length(dh_list) > 1 do
    case for item <- dh_list, item["principal_entitled"] === :true, do: item do
      [principal_entitled | _] ->
        get_dh(principal_entitled, default_value)
      [] ->
        [first | _] = dh_list
        get_dh(first, default_value)
    end
  end

  def clues(origin, egress_clue, _default_value) when (origin === :undefined or origin === :nil and egress_clue !== :undefined) do
    egress_clue
  end
  def clues(origin, _egress_clue, _default_value) when (origin !== :undefined and origin !== :nil) do
    origin
  end
  def clues(:undefined, :undefined, default_value) do
    default_value
  end

  def comorbidities(_comorbidity, []) do
    ["","",""]
  end
  def comorbidities(:undefined, _comorbidities_list) do
    ["","",""]
  end
  def comorbidities(_comorbidity, comorbidities_list) do
    [
      get_value_pipe(comorbidities_list, "number", :undefined, ""), get_value_pipe(comorbidities_list, "description", :undefined, ""), get_value_pipe(comorbidities_list, "diagnosis", "key_diagnosis", "")
    ]
  end

  def procedures([]) do
    ["","","","","","",""]
  end
  def procedures(procedures_list) do
    [
      get_value_pipe(procedures_list, "number", :undefined, "0"),
      get_value_pipe(procedures_list, "description", :undefined, ""),
      get_value_pipe(procedures_list, "diagnosis", "key_diagnosis", ""),
      get_value_pipe(procedures_list, "anesthesia_type", "key", "-1"),
      get_value_pipe(procedures_list, "quirofano_inside_outside", :undefined, ""),
      get_value_pipe(procedures_list, "operating_room_time", :undefined, ""),
      get_value_pipe(procedures_list, "professional_cedule", :undefined, "0")
    ]
  end

  def product([]) do
    ["0","-1","-1","","","-1","-1", "-1"]
  end
  def product(product_list) do
    [
      get_value_pipe(product_list, "number", :undefined, "0"),
      get_value_pipe(product_list, "birth_condition", "key", "-1"),
      get_value_pipe(product_list, "live_born_condition", "key", "-1"),
      get_value_pipe(product_list, "folio_certificate", :undefined, ""),
      get_value_pipe(product_list, "pay_5_minutes", :undefined, ""),
      get_value_pipe(product_list, "neonatal_resuscitation", :undefined, "-1"),
      get_value_pipe(product_list, "accommodation_set", :undefined, "-1"),
      get_value_pipe(product_list, "exclusive_breastfeeding", :undefined, "-1")
    ]
  end

  ####UTILERIAS####
  def get_dh(dh, default_value) do
    [Map.get(dh, "key", default_value), Map.get(dh, "is_gratuity", "-1"), Map.get(dh, "insurance_policy", ""), Map.get(dh, "check_digit", "")]
  end

  def get_value_pipe(comorbidities_list, value, :undefined, default_value) do
    list = for item <- comorbidities_list, do: Map.get(item, value, default_value)
    Enum.join(list, " | ")
  end
  def get_value_pipe(comorbidities_list, value, second, default_value) do
    list = for item <- comorbidities_list, do: Map.get(item, value, %{}) |> Map.get(second, default_value)
    Enum.join(list, " | ")
  end
end
