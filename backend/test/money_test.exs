defmodule Waves.MoneyTest do
  use ExUnit.Case, async: true
  alias Waves.Money
  test "fractional quantities round half-up per line" do
    assert {:ok, [line], total} = Money.lines([%{"description" => "Work", "quantity" => "0.125", "unit_price" => "10.04"}])
    assert line["total"] == "1.26"
    assert Decimal.equal?(total, "1.26")
  end
  test "rejects floats, negatives, scientific notation and excess money precision" do
    for value <- [0.1, "-1", "1e3", "0", "1.001", nil], do: assert({:error, _} = Money.positive(value))
    assert {:error, _} = Money.lines([])
  end
end
