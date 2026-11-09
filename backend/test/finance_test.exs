defmodule Waves.FinanceTest do
  use ExUnit.Case, async: false
  alias Waves.{Repo, Business, ApiKey, Finance, Entry, Invoice}
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    b = Repo.insert!(%Business{name: "One", currency: "KES"})
    other = Repo.insert!(%Business{name: "Two", currency: "KES"})
    key = Repo.insert!(%ApiKey{business_id: b.id, name: "Test", token_hash: "test"})
    {:ok, customer} = Finance.customer(b.id, %{"name" => "Customer"})
    {:ok, invoice} = Finance.draft(b.id, %{"customer_id" => customer.id, "due_date" => "2026-12-31", "lines" => [%{"description" => "Service", "quantity" => "1", "unit_price" => "100.00"}]})
    %{key: key, invoice: invoice, other: other}
  end
  test "issues once, allocates partial payments and balances the ledger", %{key: key, invoice: invoice} do
    assert {:ok, issued} = Finance.issue(key, invoice.id)
    assert issued.number == "INV-000001"
    assert {:error, :already_issued} = Finance.issue(key, invoice.id)
    attrs = %{"method" => "bank_transfer", "amount" => "40.00", "reference" => "BANK-1", "received_on" => "2026-10-17"}
    assert {:ok, first} = Finance.pay(key, invoice.id, attrs)
    assert {:ok, replay} = Finance.pay(key, invoice.id, attrs)
    assert first.id == replay.id
    assert {:error, :reference_conflict} = Finance.pay(key, invoice.id, %{attrs | "amount" => "41.00"})
    assert {:error, :overpayment} = Finance.pay(key, invoice.id, %{attrs | "amount" => "61.00", "reference" => "BANK-2"})
    assert {:ok, _} = Finance.pay(key, invoice.id, %{attrs | "amount" => "60.00", "reference" => "BANK-2"})
    assert Repo.get!(Invoice, invoice.id).status == "paid"
    assert length(Repo.all(Entry)) == 6
    for {_id, entries} <- Enum.group_by(Repo.all(Entry), & &1.journal_id) do
      dr = Enum.reduce(entries, Decimal.new(0), &Decimal.add(&1.debit, &2))
      cr = Enum.reduce(entries, Decimal.new(0), &Decimal.add(&1.credit, &2))
      assert Decimal.equal?(dr, cr)
    end
  end
  test "another business cannot issue an invoice or see its entries", %{key: key, invoice: invoice, other: other} do
    assert {:error, :not_found} = Finance.issue(%{key | business_id: other.id}, invoice.id)
    assert Finance.invoices(other.id) == []
    assert Finance.entries(other.id) == []
    assert Repo.get!(Invoice, invoice.id).status == "draft"
  end
end
