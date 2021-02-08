defmodule Xlsx.SrsWeb.ParserA do
  require Logger

  def age(years, _months, _days, _default_value) when (years >= 1 and years <= 120) do
    years
  end

  def age(_years, months, _days, _default_value) when (months >= 1 and months <= 11) do
    months
  end

  def age(_years, _months, days, _default_value) when (days >= 1 and days <= 29) do
    days
  end

  def age(_years, _months, _days, default_value) do
    default_value
  end

end
