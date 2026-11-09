defmodule Waves.TaxTest do
  use ExUnit.Case, async: true
  alias Waves.Money
  defp line(price), do: [%{"description" => "Service", "quantity" => "1", "unit_price" => price}]
  test "tax exclusive adds tax to net sales" do
    assert {:ok, v} = Money.invoice(line("100.00"), %{"tax_mode" => "exclusive", "tax_rate" => "16", "tax_name" => "VAT"})
    assert Decimal.equal?(v.subtotal, "100.00")
    assert Decimal.equal?(v.tax_total, "16.00")
    assert Decimal.equal?(v.total, "116.00")
  end
  test "tax inclusive extracts tax without increasing the quoted price" do
    assert {:ok, v} = Money.invoice(line("116.00"), %{"tax_mode" => "inclusive", "tax_rate" => "16"})
    assert Decimal.equal?(v.subtotal, "100.00")
    assert Decimal.equal?(v.tax_total, "16.00")
    assert Decimal.equal?(v.total, "116.00")
  end
  test "none and zero-rated tax preserve invoice totals" do
    for mode <- ["none", "exclusive", "inclusive"] do
      assert {:ok, v} = Money.invoice(line("100.00"), %{"tax_mode" => mode, "tax_rate" => "0"})
      assert Decimal.equal?(v.total, "100.00")
      assert Decimal.equal?(v.tax_total, "0")
    end
    assert {:ok, v} = Money.invoice(line("100.00"), %{"tax_mode" => "none", "tax_rate" => "16"})
    assert Decimal.equal?(v.tax_total, 0)
  end
  test "rounds tax once over the sum of already-rounded line amounts" do
    lines = for _ <- 1..3, do: %{"description" => "Small item", "quantity" => "1", "unit_price" => "0.05"}
    assert {:ok, v} = Money.invoice(lines, %{"tax_mode" => "exclusive", "tax_rate" => "10"})
    assert Decimal.equal?(v.tax_total, "0.02")
    assert Decimal.equal?(v.total, "0.17")
  end
  test "rejects invalid, negative, excessive or floating point rates" do
    for rate <- ["-1", "100.01", "16.00001", "NaN", 16.0] do
      assert {:error, _} = Money.invoice(line("100.00"), %{"tax_rate" => rate, "tax_mode" => "exclusive"})
    end
  end
end
