defmodule Waves.SimpleBilling do
  alias Waves.Money

  def enabled?(value), do: value in [true, "true"]

  def prepare(line) do
    flag = Map.get(line, "uses_duration", false)
    unit = Map.get(line, "unit", "Units")
    notes = Map.get(line, "notes", "") || ""
    duration_unit = Map.get(line, "duration_unit", "Days")

    with true <- flag in [true, false, "true", "false"],
         true <- text?(unit, 60) and String.trim(unit) != "",
         true <- text?(notes, 3000),
         {:ok, quantity} <- Money.positive(Map.get(line, "quantity", "1"), 4),
         {:ok, duration} <- duration(line, enabled?(flag)),
         true <- not enabled?(flag) or (text?(duration_unit, 60) and String.trim(duration_unit) != "") do
      quantity_text = Decimal.to_string(quantity, :normal)
      duration_text = if duration, do: Decimal.to_string(duration, :normal)
      factors = if duration do
        [%{"label" => unit, "kind" => "multiplier", "value" => quantity_text},
         %{"label" => duration_unit, "kind" => "multiplier", "value" => duration_text}]
      else
        []
      end

      calculation = line
        |> Map.put("billing_method", if(duration, do: "parameters", else: "quantity"))
        |> Map.put("quantity", quantity_text)
        |> Map.put("unit", String.trim(unit))
        |> Map.put("parameters", factors)

      display = %{"simple" => true, "quantity" => quantity_text, "display_quantity" => quantity_text,
        "effective_quantity" => Decimal.to_string(Decimal.mult(quantity, duration || Decimal.new(1)), :normal),
        "uses_duration" => enabled?(flag), "duration" => duration_text,
        "duration_unit" => if(duration, do: String.trim(duration_unit), else: nil),
        "notes" => String.trim(notes)}

      {:ok, calculation, display}
    else
      _ -> {:error, :invalid_quantity_duration_or_notes}
    end
  end

  defp duration(_, false), do: {:ok, nil}
  defp duration(line, true), do: Money.positive(Map.get(line, "duration", "1"), 4)
  defp text?(text, limit), do: is_binary(text) and String.length(text) <= limit

  def defaults(item) do
    base = %{"simple" => true, "item_id" => item.id, "description" => item.name,
      "unit_price" => Decimal.to_string(item.unit_price, :normal), "quantity" => "1",
      "unit" => item.unit, "uses_duration" => item.uses_duration,
      "duration" => "1", "duration_unit" => item.duration_unit,
      "notes" => item.default_notes || item.description || ""}

    if item.simple_billing do
      base
    else
      legacy_defaults(base, item)
    end
  end

  # Existing catalogue entries remain intact until a user saves new defaults.
  defp legacy_defaults(base, item) do
    factors = Enum.filter(item.parameters, &(&1["kind"] == "multiplier"))
    {duration_factors, quantities} = Enum.split_with(factors, fn p ->
      String.downcase(p["label"] || "") in ["day", "days", "night", "nights", "hour", "hours", "week", "weeks", "month", "months"]
    end)

    case {item.billing_method, duration_factors} do
      {"parameters", [duration]} ->
        quantity = Enum.reduce(quantities, Decimal.new(1), &Decimal.mult(Decimal.new(&1["value"]), &2))
        Map.merge(base, %{"quantity" => Decimal.to_string(quantity, :normal),
          "uses_duration" => true, "duration" => duration["value"], "duration_unit" => duration["label"]})
      {"parameters", _} ->
        quantity = Enum.reduce(factors, Decimal.new(1), &Decimal.mult(Decimal.new(&1["value"]), &2))
        Map.put(base, "quantity", Decimal.to_string(quantity, :normal))
      _ -> base
    end
    |> Map.update!("notes", fn notes ->
      details = item.parameters |> Enum.reject(&(&1["kind"] == "multiplier"))
        |> Enum.map_join("\n", &(( &1["label"] || "Detail") <> ": " <> (&1["value"] || "")))
      Enum.reject([notes, details], &(&1 == "")) |> Enum.join("\n")
    end)
  end
end
