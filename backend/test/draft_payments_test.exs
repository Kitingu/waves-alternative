defmodule Waves.DraftPaymentsTest do
  use ExUnit.Case, async: false
  alias Waves.{Repo, Business, ApiKey, Finance, Invoice, Billing}
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    b = Repo.insert!(%Business{name: "Tours", currency: "USD"})
    key = Repo.insert!(%ApiKey{business_id: b.id, name: "API", token_hash: "draft-tests"})
    {:ok, c} = Finance.customer(b.id, %{"name" => "Buyer"})
    attrs = %{"customer_id" => c.id, "due_date" => "2026-12-31", "lines" => [%{"description" => "Tour", "quantity" => "1", "unit_price" => "1000"}]}
    {:ok, invoice} = Finance.draft(b.id, attrs)
    %{business: b, key: key, invoice: invoice, attrs: attrs}
  end
  test "editing keeps identity and catches stale edits without touching issued invoices", %{key: key, invoice: invoice} do
    assert {:ok, updated} = Finance.update_draft(key, invoice.id, %{"lock_version" => invoice.lock_version, "notes" => "Updated"})
    assert updated.id == invoice.id
    assert updated.notes == "Updated"
    assert Repo.aggregate(Invoice, :count) == 1
    assert {:error, :draft_changed_reload_before_saving} = Finance.update_draft(key, invoice.id, %{"lock_version" => invoice.lock_version, "notes" => "Stale"})
    assert {:ok, _} = Finance.issue(key, invoice.id)
    assert {:error, :issued_invoice_cannot_be_edited} = Finance.update_draft(key, invoice.id, %{"lock_version" => updated.lock_version})
  end
  test "three receipts retain their methods and dates and settle the invoice", %{key: key, invoice: invoice} do
    {:ok, _} = Finance.issue(key, invoice.id)
    for {amount, method, day} <- [{"200", "cash", "18"}, {"300", "mpesa", "19"}, {"500", "bank_transfer", "20"}] do
      assert {:ok, _} = Finance.pay(key, invoice.id, %{"amount" => amount, "method" => method, "received_on" => "2026-10-" <> day, "reference" => method})
    end
    saved = Finance.invoice(key.business_id, invoice.id)
    assert saved.status == "paid"
    assert saved.payment_count == 3
    assert saved.last_payment_method == "bank_transfer"
    assert saved.last_payment_date == ~D[2026-10-20]
    assert Enum.map(Finance.payment_history(key.business_id, invoice.id), & &1.method) == ["bank_transfer", "mpesa", "cash"]
    assert Enum.count(Finance.ledger(key.business_id), &(&1.direction == "Incoming")) == 3
    assert {:error, _} = Finance.payment_values(%{"amount" => "100", "reference" => "missing-method", "received_on" => "2026-10-20"})
  end
  test "allowance counts issued invoices, while drafts and collections remain available", %{business: b, key: key, invoice: invoice, attrs: attrs} do
    {:ok, _} = Finance.issue(key, invoice.id)
    for _ <- 1..4 do
      {:ok, draft} = Finance.draft(b.id, attrs)
      assert {:ok, _} = Finance.issue(key, draft.id)
    end
    assert Billing.usage(b).remaining == 0
    assert {:ok, sixth} = Finance.draft(b.id, attrs)
    assert {:error, :subscription_required} = Finance.issue(key, sixth.id)
    assert {:ok, _} = Finance.pay(key, invoice.id, %{"amount" => "200", "method" => "cash", "reference" => "after-limit", "received_on" => "2026-10-20"})
    Repo.update!(Ecto.Changeset.change(b, subscription_status: "active"))
    assert {:ok, _} = Finance.issue(key, sixth.id)
  end
end
