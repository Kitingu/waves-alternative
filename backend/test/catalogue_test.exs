defmodule Waves.CatalogueTest do
  use ExUnit.Case, async: false
  alias Waves.{Repo, Business, Catalogue, Finance, ApiKey}
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    b = Repo.insert!(%Business{name: "Catalogue", currency: "KES"})
    other = Repo.insert!(%Business{name: "Other", currency: "KES"})
    key = Repo.insert!(%ApiKey{business_id: b.id, name: "Catalogue", token_hash: "catalogue-test"})
    {:ok, customer} = Finance.customer(b.id, %{"name" => "Buyer"})
    {:ok, item} = Catalogue.save(b.id, %{"code" => "MIC", "name" => "Microphone hire", "unit_price" => "10.00", "item_type" => "hire", "billing_method" => "parameters", "parameters" => [%{"label" => "Microphones", "kind" => "multiplier", "value" => "4"}, %{"label" => "Days", "kind" => "multiplier", "value" => "3"}]})
    %{business: b, other: other, key: key, item: item, customer: customer}
  end
  test "saved defaults and per-line overrides are independently snapshotted", %{business: b, key: key, item: item, customer: customer} do
    {:ok, invoice} = Finance.draft(b.id, %{"customer_id" => customer.id, "due_date" => "2026-12-31", "lines" => [%{"item_id" => item.id}, %{"item_id" => item.id, "unit_price" => "20.00", "parameters" => [%{"label" => "Days", "kind" => "multiplier", "value" => "2"}]}]})
    assert Decimal.equal?(invoice.total, 160)
    assert {:ok, issued} = Finance.issue(key, invoice.id)
    assert {:ok, _} = Catalogue.save(b.id, %{"unit_price" => "99.00", "is_active" => false}, item.id)
    saved = Finance.invoice(b.id, issued.id)
    assert hd(saved.lines)["unit_price"] == "10.00"
    assert hd(saved.lines)["item_code"] == "MIC"
    assert Decimal.equal?(saved.total, 160)
    assert {:error, _} = Catalogue.resolve(b.id, [%{"item_id" => item.id}])
  end
  test "foreign business cannot read, update or use a saved item", %{other: other, item: item} do
    assert Catalogue.get(other.id, item.id) == nil
    assert {:error, :not_found} = Catalogue.save(other.id, %{"name" => "Changed"}, item.id)
    assert {:error, _} = Catalogue.resolve(other.id, [%{"item_id" => item.id}])
  end
  test "duplicate item codes fail cleanly", %{business: b} do
    assert {:error, %Ecto.Changeset{}} = Catalogue.save(b.id, %{"code" => "MIC", "name" => "Duplicate", "unit_price" => "10"})
  end
  test "new invoices always use the company colour", %{business: b, key: key, customer: customer} do
    attrs = %{"customer_id" => customer.id, "due_date" => "2026-12-31", "accent_color" => "#4f46e5", "lines" => [%{"description" => "Service", "quantity" => "1", "unit_price" => "100"}]}
    {:ok, invoice} = Finance.draft(b.id, attrs)
    {:ok, issued} = Finance.issue(key, invoice.id)
    assert issued.business_snapshot["accent_color"] == "#174f47"
    assert Repo.get!(Business, b.id).accent_color == "#174f47"
    assert invoice.accent_color_override == nil
  end

end
