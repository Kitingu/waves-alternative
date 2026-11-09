defmodule Waves.Money do
  @moduledoc "Explicit decimal input and per-line half-up rounding for the first two-decimal-currency release."
  def positive(value, scale \\ 2)
  def positive(value, scale) when is_binary(value) and byte_size(value) <= 64 do
    if Regex.match?(~r/\A\d+(\.\d+)?\z/, value) do
      decimal = Decimal.new(value)
      if Decimal.compare(decimal, 0) == :gt and Decimal.equal?(decimal, Decimal.round(decimal, scale)),
        do: {:ok, decimal}, else: {:error, :invalid_amount}
    else
      {:error, :invalid_amount}
    end
  end
  def positive(_, _), do: {:error, :invalid_amount}
  def lines(lines) when is_list(lines) and length(lines) in 1..100 do
    Enum.reduce_while(lines, {:ok, [], Decimal.new(0)}, fn line, {:ok, result, sum} ->
      case Waves.BillingLine.normalize(line) do
        {:ok, item} -> {:cont, {:ok, [item | result], Decimal.add(sum, Decimal.new(item["total"]))}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, result, sum} ->
        if Decimal.compare(sum, "9999999999999999.99") == :gt,
          do: {:error, :invalid_lines}, else: {:ok, Enum.reverse(result), sum}
      error -> error
    end
  end
  def lines(_), do: {:error, :invalid_lines}
  def invoice(lines, attrs) do
    mode = attrs["tax_mode"] || "none"
    rate_text = attrs["tax_rate"] || "0"
    name = attrs["tax_name"] || "Tax"
    with true <- mode in ["none", "exclusive", "inclusive"],
         true <- is_binary(name) and String.trim(name) != "" and byte_size(name) <= 200,
         {:ok, rate} <- rate(rate_text),
         {:ok, items, sum} <- lines(lines) do
      applied_rate = if mode == "none", do: Decimal.new(0), else: rate
      tax = case mode do
        "exclusive" -> Decimal.mult(sum, applied_rate) |> Decimal.div(100) |> Decimal.round(2, :half_up)
        "inclusive" -> Decimal.mult(sum, applied_rate) |> Decimal.div(Decimal.add(100, applied_rate)) |> Decimal.round(2, :half_up)
        "none" -> Decimal.new(0)
      end
      subtotal = if mode == "inclusive", do: Decimal.sub(sum, tax), else: sum
      total = Decimal.add(subtotal, tax)
      if Decimal.compare(total, "9999999999999999.99") == :gt do
        {:error, :invalid_amount}
      else
        {:ok, %{lines: items, subtotal: subtotal, tax_total: tax, total: total,
          tax_mode: mode, tax_rate: applied_rate, tax_name: String.trim(name)}}
      end
    else
      _ -> {:error, :invalid_tax_or_lines}
    end
  end
  defp rate(value) when is_binary(value) and byte_size(value) <= 12 do
    if Regex.match?(~r/\A\d+(\.\d{1,4})?\z/, value) do
      rate = Decimal.new(value)
      if Decimal.compare(rate, 100) != :gt, do: {:ok, rate}, else: {:error, :invalid_tax_rate}
    else
      {:error, :invalid_tax_rate}
    end
  end
  defp rate(_), do: {:error, :invalid_tax_rate}

end
