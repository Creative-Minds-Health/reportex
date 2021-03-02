defmodule Xlsx.Date.Date do
  require Logger
  alias Xlsx.Integer.Integer, as: IntLib

  def string_time(date, separator) do
    string_number(date.hour) <> separator <> string_number(date.minute) <> separator <> string_number(date.second)
  end
  def string_date(date, separator) do
    string_number(date.day) <> separator <> string_number(date.month) <> separator <> string_number(date.year)
  end
  def date_rage({from, to}, days) do
    from_date = DateTime.to_date(from)
    to_date = DateTime.shift_zone!(to, "America/Mexico_City") |> DateTime.to_date()
    date_rage({from_date, to_date}, {:diff, Date.diff(to_date, from_date)}, days - 1)
      |> Enum.reverse()
  end
  def transform_date_range([], _config) do
    []
  end
  def transform_date_range([date|t], config) do
    [
      %{
        Map.get(config, "from") => Map.get(date, "from") |> from_date(),
        Map.get(config, "to") => Map.get(date, "to") |> to_date()
      } |
      transform_date_range(t, config)
    ]
  end

  def get_date_now(:undefined, separator) do
    today = DateTime.utc_now
    [today.year, today.month, today.day]
    Enum.join [IntLib.get_number(today.day), IntLib.get_number(today.month), today.year], separator
  end

  def get_date_now(date, separator) do
    [date.year, date.month, date.day]
    Enum.join [IntLib.get_number(date.day), IntLib.get_number(date.month), date.year], separator
  end


  def file_name_date(separator) do
    date = DateTime.now!("America/Mexico_City")
    [time | _] = DateTime.to_time(date) |> Time.to_string() |> String.replace(":", "-") |> String.split(".")
    {year, month, day} = Date.to_erl(date)
    string_number(day) <> separator <> string_number(month) <> separator <> string_number(year) <> "_" <> time
  end
  defp date_rage({from, to}, {:diff, diff}, days) when diff > days do
    decrease_date = Date.add(to, -days)
    new_to = Date.add(to, -days) |> Date.add(-1)
    [ %{"from" => decrease_date, "to" => to} | date_rage({from, new_to}, {:diff, Date.diff(new_to, from)}, days)]
  end
  defp date_rage({from, to}, {:diff, _diff}, _days) do
    [%{"from" => from, "to" => to}]
  end


  def string_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end
  def string_number(number) do
    Integer.to_string(number);
  end

  defp from_date(date) do
    DateTime.new!(date, Time.new!(00,00,00), "America/Mexico_City") |> DateTime.shift_zone!("Etc/UTC")
  end
  defp to_date(date) do
    DateTime.new!(date, Time.new!(23,59,59), "America/Mexico_City") |> DateTime.shift_zone!("Etc/UTC")
  end

end
