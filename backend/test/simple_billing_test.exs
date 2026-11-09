defmodule Waves.SimpleBillingTest do
  use ExUnit.Case, async: true

  alias Waves.BillingLine

  defp line(overrides) do
    Map.merge(%{"simple" => true, "description" => "Microphone hire", "quantity" => "4",
      "unit" => "Microphones", "unit_price" => "10.00", "uses_duration" => true,
      "duration" => "3", "duration_unit" => "Days", "notes" => "Venue: Conference Hall"}, overrides)
  end

  test "hire shows base quantity and duration without double counting" do
    assert {:ok, value} = BillingLine.normalize(line(%{}))
    assert value["total"] == "120.00"
    assert value["quantity"] == "4"
    assert value["effective_quantity"] == "12"
    assert value["notes"] == "Venue: Conference Hall"
    assert BillingLine.explanation(value) == "4 Microphones × 3 Days"
    assert {:ok, replay} = BillingLine.normalize(value)
    assert replay["total"] == value["total"]
  end

  test "a three-day tour at 150 costs 450" do
    assert {:ok, value} = BillingLine.normalize(line(%{"quantity" => "1", "unit" => "Tour", "unit_price" => "150.00"}))
    assert value["total"] == "450.00"
  end

  test "removing duration ignores a retained duration value" do
    assert {:ok, value} = BillingLine.normalize(line(%{"uses_duration" => "false", "duration" => "99"}))
    assert value["total"] == "40.00"
    assert value["duration"] == nil
  end

  test "fixed delivery is just quantity one without duration" do
    assert {:ok, value} = BillingLine.normalize(line(%{"quantity" => "1", "unit" => "Charge", "unit_price" => "30.00", "uses_duration" => false}))
    assert value["total"] == "30.00"
  end

  test "rejects invalid quantities and duration instead of guessing" do
    for invalid <- ["0", "-2", "NaN", "1.00001"] do
      assert {:error, _} = BillingLine.normalize(line(%{"duration" => invalid}))
      assert {:error, _} = BillingLine.normalize(line(%{"quantity" => invalid}))
    end
  end
end
