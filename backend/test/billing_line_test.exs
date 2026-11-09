defmodule Waves.BillingLineTest do
  use ExUnit.Case, async: true
  alias Waves.{BillingLine, Money}
  defp factor(label, value), do: %{"label" => label, "value" => value, "kind" => "multiplier"}
  test "three tour days at 150 is 450" do
    assert {:ok, line} = BillingLine.normalize(%{"description" => "Tour", "billing_method" => "parameters", "unit_price" => "150.00", "parameters" => [factor("Days", "3")]})
    assert Decimal.equal?(Decimal.new(line["total"]), "450")
    assert BillingLine.explanation(line) == "3 Days"
  end
  test "each line uses its own factors and descriptive fields never multiply" do
    microphone = %{"description" => "Microphone hire", "billing_method" => "parameters", "unit_price" => "10.00", "parameters" => [factor("Microphones", "4"), factor("Days", "3"), %{"label" => "Venue", "kind" => "text", "value" => "Conference Hall"}, %{"label" => "Collection", "kind" => "date", "value" => "2026-10-20"}]}
    speaker = %{"description" => "Speaker hire", "billing_method" => "parameters", "unit_price" => "40.00", "parameters" => [factor("Speakers", "2"), factor("Days", "3")]}
    delivery = %{"description" => "Delivery", "billing_method" => "fixed", "unit_price" => "30.00", "quantity" => "999"}
    assert {:ok, [mic, speakers, fixed], total} = Money.lines([microphone, speaker, delivery])
    assert Decimal.equal?(Decimal.new(mic["total"]), 120)
    assert Decimal.equal?(Decimal.new(speakers["total"]), 240)
    assert Decimal.equal?(Decimal.new(fixed["total"]), 30)
    assert Decimal.equal?(total, 390)
    assert length(mic["parameters"]) == 4
  end
  test "supports fractional durations and rounds only the final line amount" do
    assert {:ok, line} = BillingLine.normalize(%{"description" => "Consulting", "billing_method" => "parameters", "unit_price" => "99.99", "parameters" => [factor("Hours", "1.25")]})
    assert line["total"] == "124.99"
  end
  test "legacy quantity lines still calculate identically" do
    assert {:ok, line} = BillingLine.normalize(%{"description" => "Original", "quantity" => "3", "unit_price" => "150.00"})
    assert Decimal.equal?(Decimal.new(line["total"]), 450)
  end
  test "rejects missing factors, ambiguous quantity billing and invalid values" do
    base = %{"description" => "Hire", "billing_method" => "parameters", "unit_price" => "10"}
    assert {:error, _} = BillingLine.normalize(base)
    for value <- ["0", "-1", "NaN", "2.00001", "1e4"] do
      assert {:error, _} = BillingLine.normalize(Map.put(base, "parameters", [factor("Days", value)]))
    end
    assert {:error, _} = BillingLine.normalize(Map.merge(base, %{"billing_method" => "quantity", "quantity" => "1", "parameters" => [factor("Days", "3")]}))
    assert {:error, _} = BillingLine.normalize(Map.put(base, "parameters", [%{"label" => "Date", "kind" => "date", "value" => "2026-02-31"}]))
  end
end
