defmodule Xlsx.SrsWeb.Suive.Concat do
  require Logger

  def concat_data(_data, diagnosis_template, []) do
    diagnosis_template
  end

  def concat_data(data, diagnosis_template, [h|t]) do
    new_group_template = iterate_group_template(Map.get(diagnosis_template, h, []), Map.get(data, h, []), [])
    concat_data(data, Map.put(diagnosis_template, h, new_group_template), t)
  end

  def iterate_group_template([], [], new_group) do
    new_group
  end
  def iterate_group_template([ht | tt], [hd | td], new_group) do
    new_group_ages = case ht["name"] === hd["name"] and  ht["epiKey"] === hd["epiKey"] do
      true -> iterate_group_ages(ht["groupAges"], hd["groupAges"], [])
      _-> ht["groupAges"]
    end
    iterate_group_template(tt, td, new_group ++ [Map.put(ht, "groupAges", new_group_ages)])
  end

  def iterate_group_ages([], [], group_ages) do
    group_ages
  end
  def iterate_group_ages([hat | tat], [had | tad], group_ages) do
    new_group_ages = case hat["name"] === had["name"] do
      true ->
        Map.put(hat, "mens", Map.get(hat, "mens") + had["mens"]) |> Map.put("womens", Map.get(hat, "womens") + had["womens"])
      _ -> hat
    end
    iterate_group_ages(tat, tad, group_ages ++ [new_group_ages])
  end
end
