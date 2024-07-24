defmodule Xlsx.Integer.Integer do
  require Logger
  def get_number(number) when number < 10 do
    "0" <> Integer.to_string(number);
  end
  def get_number(number) do
    number;
  end
end
