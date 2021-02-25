defmodule Xlsx.Date.Date do
  require Logger

  def string_time(date, separator) do
    string_number(date.hour) <> separator <> string_number(date.minute) <> separator <> string_number(date.second)
  end

  def string_date(date, separator) do
    string_number(date.day) <> separator <> string_number(date.month) <> separator <> string_number(date.year)
  end

  def range_date_by({from, to}, days) do
    from_date = DateTime.to_date(from)
    to_date = DateTime.shift_zone!(to, "America/Mexico_City") |> DateTime.to_date()
    range_date_by({from_date, to_date}, {:diff, Date.diff(to_date, from_date)}, days - 1)
  end
  def range_date_by({from, to}, {:diff, diff}, days) when diff > days do
    decrease_date = Date.add(to, -days)
    new_to = Date.add(to, -days) |> Date.add(-1)
    [ %{"from" => decrease_date, "to" => to} | range_date_by({from, new_to}, {:diff, Date.diff(new_to, from)}, days)]
  end
  def range_date_by({from, to}, {:diff, _diff}, _days) do
    %{"from" => from, "to" => to}
  end


  defp string_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end
  defp string_number(number) do
    Integer.to_string(number);
  end

end
