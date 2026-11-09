defmodule Waves.BillingLine do
  alias Waves.Money
  @limit Decimal.new("9999999999999999.99")
  def parameters(values) when is_list(values) and length(values) <= 12 do
    Enum.reduce_while(values, {:ok, []}, fn p, {:ok, acc} ->
      with %{"label" => label, "kind" => kind, "value" => value} <- p,
           true <- text?(label, 60) and String.trim(label) != "",
           true <- kind in ["multiplier", "text", "date"],
           true <- text?(value, 500),
           unit <- Map.get(p, "unit", ""), true <- text?(unit, 60),
           true <- valid_value?(kind, value) do
        {:cont, {:ok, acc ++ [%{"label" => String.trim(label), "kind" => kind, "value" => value, "unit" => unit}]}}
      else
        _ -> {:halt, {:error, :invalid_parameters}}
      end
    end)
  end
  def parameters(_), do: {:error, :invalid_parameters}
  def normalize(line) when is_map(line) do
    if Waves.SimpleBilling.enabled?(line["simple"]) do
      with {:ok, calculation, display} <- Waves.SimpleBilling.prepare(line),
           {:ok, normalized} <- normalize_legacy(calculation) do
        {:ok, Map.merge(normalized, display)}
      end
    else
      normalize_legacy(line)
    end
  end

  def normalize(_), do: {:error, :invalid_billing_line}

  defp normalize_legacy(line) when is_map(line) do
    method = Map.get(line, "billing_method", "quantity")
    with true <- method in ["fixed", "quantity", "parameters"],
         text <- line["description"], true <- text?(text, 1000) and String.trim(text) != "",
         unit <- Map.get(line, "unit", "Units"), true <- text?(unit, 60),
         {:ok, price} <- Money.positive(line["unit_price"]),
         {:ok, params} <- parameters(Map.get(line, "parameters", [])),
         {:ok, quantity} <- quantity(method, line, params),
         total <- Decimal.mult(quantity, price) |> Decimal.round(2, :half_up),
         true <- Decimal.compare(total, 0) == :gt and Decimal.compare(total, @limit) != :gt do
      item = %{"description" => String.trim(text), "unit_price" => Decimal.to_string(price, :normal),
        "quantity" => Decimal.to_string(quantity, :normal), "total" => Decimal.to_string(total, :normal),
        "billing_method" => method, "unit" => unit, "parameters" => params}
      {:ok, Map.merge(item, Map.take(line, ["item_id", "item_code", "item_name"]))}
    else
      _ -> {:error, :invalid_billing_line}
    end
  end
  defp quantity(method, line, params) do
    factors = Enum.filter(params, &(&1["kind"] == "multiplier"))
    case {method, factors} do
      {"fixed", []} -> {:ok, Decimal.new(1)}
      {"quantity", []} -> Money.positive(line["quantity"], 4)
      {"parameters", [_ | _]} ->
        result = Enum.reduce(factors, Decimal.new(1), &Decimal.mult(Decimal.new(&1["value"]), &2))
        if Decimal.compare(result, @limit) != :gt, do: {:ok, result}, else: {:error, :quantity_too_large}
      _ -> {:error, :invalid_billing_parameters}
    end
  end
  defp valid_value?("multiplier", value), do: match?({:ok, _}, Money.positive(value, 4))
  defp valid_value?("text", _), do: true
  defp valid_value?("date", ""), do: true
  defp valid_value?("date", value), do: match?({:ok, _}, Date.from_iso8601(value))
  defp text?(value, length), do: is_binary(value) and String.length(value) <= length
  def explanation(%{"simple" => true} = line) do
    quantity = line["display_quantity"] <> " " <> line["unit"]
    if line["uses_duration"], do: quantity <> " × " <> line["duration"] <> " " <> line["duration_unit"], else: quantity
  end

  def explanation(line) do
    case line["billing_method"] || "quantity" do
      "fixed" -> "Fixed charge"
      "parameters" -> line |> Map.get("parameters", []) |> Enum.filter(&(&1["kind"] == "multiplier")) |> Enum.map_join(" × ", &(&1["value"] <> " " <> &1["label"]))
      _ -> (line["quantity"] || "1") <> " " <> (line["unit"] || "Units")
    end
  end
end
