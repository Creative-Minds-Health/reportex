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

end
