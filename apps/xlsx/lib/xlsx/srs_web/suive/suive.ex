defmodule Xlsx.SrsWeb.Suive.Suive do
  require Logger

  def create_structure_data("ENFERMEDADES NO TRANSMISIBLES", diagnosis) do
    %{"group1" => diagnosis}
  end

  def create_structure_data("ENFERMEDADES  TRANSMISIBLES", diagnosis) do
    %{"group2" => diagnosis}
  end

  # def search_diagnosis(groups, []) do
  #   :ok
  # end
  def search_diagnosis(groups, diagnosis_template, []) do
    diagnosis_template
  end
  def search_diagnosis(groups, diagnosis_template, [h|t]) do
    new_group_template = iterate_group_template(Map.get(diagnosis_template, h, []), groups)
    search_diagnosis(groups, Map.put(diagnosis_template, h, new_group_template), t)
  end

  def iterate_group_template([], groups) do
    []
  end
  def iterate_group_template([h|t], groups) do
    [iterate_diagnosis_template(h, groups) | iterate_group_template(t, groups)]
  end

  def iterate_diagnosis_template(diagnosis, []) do
    diagnosis
  end
  def iterate_diagnosis_template(diagnosis, [h|t]) do
    [key] = Map.keys(h)
    new_diagnosis = iterate_diagnosis_results(diagnosis, h[key])
    iterate_diagnosis_template(new_diagnosis, t)
  end

  def iterate_diagnosis_results(diagnosis, []) do
    diagnosis
  end
  def iterate_diagnosis_results(diagnosis, [h|t]) do
    new_group_ages = case search_diagnosis(h["diagnosis"], diagnosis["key"], diagnosis["specific"]) do
      true ->
        update_group_ages(h["genders"], diagnosis["groupAges"])
      _-> diagnosis["groupAges"]
    end

    iterate_diagnosis_results(Map.put(diagnosis, "groupAges", new_group_ages), t)
  end

  def search_diagnosis(key, key_list, specific) do
    compare_key = case specific do
      false ->
        [new_key | _] = String.split(key, ".")
        new_key
      _ -> key
    end

    compare_key in key_list
  end

  def update_group_ages(_genders, []) do
    []
  end
  def update_group_ages(genders, [h|t]) do
    [iterate_genders(genders, h) | update_group_ages(genders, t)]
  end

  def iterate_genders([h|t], group_age_item) do
    name = group_age_item["name"]
    case {Map.get(h, name, 0), Map.get(h, "gender", :nill)} do
      {0, _} -> group_age_item
      {number, 1} ->
        Map.put(group_age_item, "mens", Map.get(group_age_item, "mens") + number)
      {number, 2} ->
        Map.put(group_age_item, "womens", Map.get(group_age_item, "womens") + number)
    end
  end
end
