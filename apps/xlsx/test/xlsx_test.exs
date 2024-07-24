defmodule XlsxTest do
  use ExUnit.Case
  doctest Xlsx

  test "greets the world" do
    assert Xlsx.hello() == :world
  end
end
