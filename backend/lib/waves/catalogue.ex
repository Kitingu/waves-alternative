defmodule Waves.Catalogue do
  import Ecto.Query
  import Ecto.Changeset
  alias Waves.{Repo, CatalogueItem, BillingLine}
  def list(business), do: Repo.all(from i in CatalogueItem, where: i.business_id == ^business, order_by: i.name)
  def get(business, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get_by(CatalogueItem, id: uuid, business_id: business)
      _ -> nil
    end
  end
  def save(business, attrs, id \\ nil) do
    item = if id, do: get(business, id), else: %CatalogueItem{business_id: business}
    if item do
      cs = cast(item, attrs, [:code, :name, :description, :category, :item_type, :billing_method, :unit, :unit_price, :parameters, :is_active, :simple_billing, :uses_duration, :duration_unit, :default_notes])
        |> validate_required([:code, :name, :item_type, :billing_method, :unit, :unit_price, :duration_unit, :uses_duration, :simple_billing])
        |> validate_format(:code, ~r/\A[A-Za-z0-9_-]{1,50}\z/)
        |> validate_length(:name, max: 200) |> validate_length(:description, max: 1000)
        |> validate_length(:unit, max: 60) |> validate_length(:category, max: 100)
        |> validate_length(:duration_unit, min: 1, max: 60)
        |> validate_length(:default_notes, max: 3000)
        |> validate_inclusion(:item_type, ["product", "service", "hire"])
        |> validate_inclusion(:billing_method, ["fixed", "quantity", "parameters"])
        |> validate_number(:unit_price, greater_than: 0, less_than_or_equal_to: Decimal.new("9999999999999999.99"))
        |> validate_change(:unit_price, fn _, v -> if Decimal.equal?(v, Decimal.round(v, 2)), do: [], else: [unit_price: "requires at most two decimal places"] end)
        |> unique_constraint([:business_id, :code])
      cs = case BillingLine.parameters(get_field(cs, :parameters, [])) do
        {:ok, params} ->
          multipliers = Enum.count(params, &(&1["kind"] == "multiplier"))
          if (get_field(cs, :billing_method) == "parameters" and multipliers > 0) or (get_field(cs, :billing_method) != "parameters" and multipliers == 0),
            do: put_change(cs, :parameters, params), else: add_error(cs, :parameters, "must match the selected billing method")
        _ -> add_error(cs, :parameters, "contains invalid defaults")
      end
      Repo.insert_or_update(cs)
    else
      {:error, :not_found}
    end
  end

  def save_simple(business, attrs, id \\ nil) do
    item = if id, do: get(business, id)

    if id && is_nil(item) do
      {:error, :not_found}
    else
      code = if item, do: item.code, else: "ITEM-" <> Base.encode16(:crypto.strong_rand_bytes(6))
      values = Map.take(attrs, ["name", "unit", "unit_price", "uses_duration", "duration_unit", "default_notes"])
        |> Map.merge(%{"code" => code, "simple_billing" => true, "billing_method" => "quantity", "parameters" => []})
      save(business, values, id)
    end
  end

  # Resolve saved defaults within the current business before copying them into the document.
  def resolve(business, lines, existing \\ [])
  def resolve(business, lines, existing) when is_list(lines) and length(lines) in 1..100 do
    Enum.reduce_while(lines, {:ok, []}, fn line, {:ok, acc} ->
      saved = if is_map(line), do: Enum.find(existing, &(is_binary(line["item_id"]) and &1["item_id"] == line["item_id"]))
      response = if saved, do: {:ok, Map.merge(saved, Map.drop(line, ["item_code", "item_name"]))}, else: resolve_line(business, line)
      case response do
        {:ok, resolved} -> {:cont, {:ok, acc ++ [resolved]}}
        error -> {:halt, error}
      end
    end)
  end
  def resolve(_, _, _), do: {:error, :invalid_lines}
  defp resolve_line(business, %{"item_id" => id} = line) when is_binary(id) and id != "" do
    case get(business, id) do
      %CatalogueItem{is_active: true} = item ->
        defaults = %{"description" => item.description || item.name, "unit_price" => Decimal.to_string(item.unit_price, :normal),
          "billing_method" => item.billing_method, "unit" => item.unit, "quantity" => "1", "parameters" => item.parameters}
        defaults = if item.simple_billing, do: Map.merge(defaults, Waves.SimpleBilling.defaults(item)), else: defaults
        resolved = Map.merge(defaults, Map.drop(line, ["item_code", "item_name"]))
          |> Map.merge(%{"item_id" => item.id, "item_code" => item.code, "item_name" => item.name})
        {:ok, resolved}
      _ -> {:error, :item_unavailable}
    end
  end
  defp resolve_line(_, line) when is_map(line), do: {:ok, Map.drop(line, ["item_id", "item_code", "item_name"])}
  defp resolve_line(_, _), do: {:error, :invalid_lines}
end
