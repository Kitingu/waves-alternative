defmodule Waves.CustomizationTest do
  use ExUnit.Case, async: false
  alias Waves.{Repo, Business, ApiKey, Finance, Settings, Entry, InvoiceDocument}
  import Ecto.Query
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    business = Repo.insert!(%Business{name: "Original Ltd", currency: "KES"})
    key = Repo.insert!(%ApiKey{business_id: business.id, name: "Test", token_hash: "custom-test"})
    {:ok, customer} = Finance.customer(business.id, %{"name" => "Buyer <script>alert(1)</script>", "address" => "Buyer address"})
    %{key: key, customer: customer}
  end
  defp draft(key, customer) do
    Finance.draft(key.business_id, %{"customer_id" => customer.id, "due_date" => "2026-12-31", "lines" => [%{"description" => "Consulting", "quantity" => "1", "unit_price" => "100.00"}]})
  end
  test "settings affect new invoices and tax credits post to liability", %{key: key, customer: customer} do
    assert {:ok, _} = Settings.save(key, %{"tax_name" => "VAT", "tax_mode" => "exclusive", "tax_rate" => "16", "invoice_prefix" => "ACME-"})
    {:ok, invoice} = draft(key, customer)
    assert Decimal.equal?(invoice.total, "116")
    {:ok, issued} = Finance.issue(key, invoice.id)
    assert issued.number == "ACME-000001"
    assert Decimal.equal?(Repo.one(from e in Entry, where: e.account == "4000", select: e.credit), "100")
    assert Decimal.equal?(Repo.one(from e in Entry, where: e.account == "2100", select: e.credit), "16")
    assert issued.customer_snapshot["address"] == "Buyer address"
    assert {:ok, _} = Settings.save(key, %{"name" => "Renamed Ltd", "tax_rate" => "20", "invoice_template" => "classic"})
    persisted = Finance.invoice(key.business_id, issued.id)
    assert persisted.business_snapshot["name"] == "Original Ltd"
    assert persisted.business_snapshot["invoice_template"] == "modern"
    assert Decimal.equal?(persisted.total, "116")
    html = InvoiceDocument.render(persisted)
    assert html =~ "Original Ltd"
    refute html =~ "Renamed Ltd"
    assert html =~ "&lt;script&gt;"
    refute html =~ "<script>alert(1)</script>"
  end
  test "changing tax defaults does not recalculate an existing draft", %{key: key, customer: customer} do
    {:ok, invoice} = draft(key, customer)
    {:ok, _} = Settings.save(key, %{"tax_rate" => "16", "tax_mode" => "exclusive"})
    {:ok, issued} = Finance.issue(key, invoice.id)
    assert Decimal.equal?(issued.total, "100")
    assert Decimal.equal?(issued.tax_total, "0")
  end
  test "rejects invalid style inputs and prevents currency/sequence injection", %{key: key} do
    assert {:error, _} = Settings.save(key, %{"accent_color" => "red; background:url(https://example.com)"})
    assert {:error, _} = Settings.save(key, %{"invoice_prefix" => "../bad"})
    assert {:error, _} = Settings.save(key, %{"tax_rate" => "16.12345"})
    assert {:ok, saved} = Settings.save(key, %{"currency" => "USD", "invoice_sequence" => 500})
    assert saved.currency == "KES"
    assert saved.invoice_sequence == 0
  end
  test "image removal cannot modify issued image snapshots", %{key: key, customer: customer} do
    png = File.read!(Path.join(__DIR__, "fixtures/branding.png"))
    uri = "data:image/png;base64," <> Base.encode64(png)
    assert Waves.BrandAsset.valid_data_uri?(uri)
    assert {:ok, _} = Settings.save(key, %{}, %{stamp_data: uri})
    {:ok, invoice} = draft(key, customer)
    {:ok, issued} = Finance.issue(key, invoice.id)
    assert {:ok, _} = Settings.save(key, %{}, %{stamp_data: nil})
    assert Finance.invoice(key.business_id, issued.id).business_snapshot["stamp_data"] == uri
    refute Waves.BrandAsset.valid_png?("not a png")
    refute Waves.BrandAsset.valid_png?(binary_part(png, 0, 32))
  end
end
