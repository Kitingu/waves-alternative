defmodule Waves.SimpleCatalogueTest do
  use ExUnit.Case, async: false

  alias Waves.{Repo, Business, Catalogue, Finance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    business = Repo.insert!(%Business{name: "Simple business", currency: "KES"})
    {:ok, customer} = Finance.customer(business.id, %{"name" => "Buyer"})
    %{business: business, customer: customer}
  end

  test "save a hire item without declaring codes or formulas", %{business: business, customer: customer} do
    assert {:ok, item} = Catalogue.save_simple(business.id, %{"name" => "Microphone hire", "unit" => "Microphones", "unit_price" => "10.00", "uses_duration" => true, "duration_unit" => "Days"})
    assert item.simple_billing
    assert item.code =~ "ITEM-"
    {:ok, invoice} = Finance.draft(business.id, %{"customer_id" => customer.id, "due_date" => "2026-12-01", "lines" => [%{"item_id" => item.id, "quantity" => "4", "duration" => "3"}]})
    assert Decimal.equal?(invoice.total, "120")
    assert hd(invoice.lines)["duration_unit"] == "Days"
    assert {:ok, _} = Catalogue.save_simple(business.id, %{"unit_price" => "20.00"}, item.id)
    assert Decimal.equal?(Finance.invoice(business.id, invoice.id).total, "120")
  end

  test "editing simple defaults cannot change an existing item code", %{business: business} do
    {:ok, item} = Catalogue.save_simple(business.id, %{"name" => "Delivery", "unit" => "Charge", "unit_price" => "30"})
    assert {:ok, saved} = Catalogue.save_simple(business.id, %{"name" => "Delivery service", "code" => "INJECTED"}, item.id)
    assert saved.code == item.code
  end
end
