defmodule Xlsx.Date.Date do
  require Logger

  def string_time(date, separator) do
    string_number(date.hour) <> separator <> string_number(date.minute) <> separator <> string_number(date.second)
  end

  def string_date(date, separator) do
    string_number(date.day) <> separator <> string_number(date.month) <> separator <> string_number(date.year)
  end

  defp string_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end

  defp string_number(number) do
    Integer.to_string(number);
  end

end
