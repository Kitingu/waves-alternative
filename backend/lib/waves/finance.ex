defmodule Waves.Finance do
  import Ecto.Query
  alias Waves.{Repo, Business, Customer, Invoice, Payment, Journal, Entry, Audit, Money, Settings, Catalogue, Billing}
  def customers(business), do: Repo.all(from c in Customer, where: c.business_id == ^business, order_by: c.name)
  def invoices(business) do
    invoices = Repo.all(from i in Invoice, where: i.business_id == ^business, order_by: [desc: i.inserted_at], limit: 200)
    ids = Enum.map(invoices, & &1.id)
    histories = Repo.all(from p in Payment, where: p.business_id == ^business and p.invoice_id in ^ids, order_by: [desc: p.received_on, desc: p.inserted_at]) |> Enum.group_by(& &1.invoice_id)
    Enum.map(invoices, &decorate_invoice(&1, Map.get(histories, &1.id, [])))
  end
  def entries(business), do: Repo.all(from e in Entry, where: e.business_id == ^business, order_by: [desc: e.inserted_at], limit: 500)
  def customer(business, attrs) do
    %Customer{business_id: business}
    |> Ecto.Changeset.cast(attrs, [:name, :email, :address, :phone, :tax_id])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 200)
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> Ecto.Changeset.validate_length(:address, max: 3000)
    |> Ecto.Changeset.validate_length(:phone, max: 100)
    |> Ecto.Changeset.validate_length(:tax_id, max: 100)
    |> Repo.insert()
  end

  def invoice(business_id, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> case Repo.get_by(Invoice, id: uuid, business_id: business_id) do
        nil -> nil
        invoice -> decorate_invoice(invoice, payment_history(business_id, uuid))
      end
      _ -> nil
    end
  end
  def draft(business_id, attrs) do
    with {:ok, record} <- build_draft(business_id, attrs), do: Repo.insert(record)
  end

  def update_draft(actor, id, attrs) do
    Repo.transaction(fn ->
      Repo.one!(from b in Business, where: b.id == ^actor.business_id, lock: "FOR UPDATE")
      invoice = locked_invoice(actor.business_id, id)
      if invoice.status != "draft", do: Repo.rollback(:issued_invoice_cannot_be_edited)
      version = case attrs["lock_version"] do
        n when is_integer(n) -> n
        text when is_binary(text) -> case Integer.parse(text) do {n, ""} -> n; _ -> nil end
        _ -> nil
      end
      if version != invoice.lock_version, do: Repo.rollback(:draft_changed_reload_before_saving)
      defaults = %{"customer_id" => invoice.customer_id, "due_date" => Date.to_iso8601(invoice.due_date),
        "lines" => invoice.lines, "notes" => invoice.notes, "terms" => invoice.terms,
        "tax_name" => invoice.tax_name, "tax_mode" => invoice.tax_mode, "tax_rate" => Decimal.to_string(invoice.tax_rate, :normal)}
      case build_draft(actor.business_id, Map.merge(defaults, Map.take(attrs, Map.keys(defaults))), invoice.lines) do
        {:ok, built} ->
          values = Map.from_struct(built) |> Map.take([:customer_id, :due_date, :lines, :subtotal, :tax_total, :total, :tax_name, :tax_rate, :tax_mode, :notes, :terms]) |> Map.put(:accent_color_override, nil)
          saved = Repo.update!(invoice |> Ecto.Changeset.change(values) |> Ecto.Changeset.optimistic_lock(:lock_version))
          audit(actor, "invoice.draft_updated", saved.id)
          saved
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp build_draft(business_id, attrs, existing_lines \\ []) do
    business = Repo.get!(Business, business_id)
    tax = %{"tax_mode" => business.tax_mode, "tax_rate" => Decimal.to_string(business.tax_rate, :normal), "tax_name" => business.tax_name}
      |> Map.merge(Map.take(attrs, ["tax_mode", "tax_rate", "tax_name"]))
    with {:ok, customer_id} <- Ecto.UUID.cast(attrs["customer_id"]),
         %Customer{} <- Repo.get_by(Customer, id: customer_id, business_id: business_id),
         {:ok, due_date} <- parse_date(attrs["due_date"]),
         {:ok, resolved_lines} <- Catalogue.resolve(business_id, attrs["lines"], existing_lines),
         {:ok, values} <- Money.invoice(resolved_lines, tax),
         true <- optional_text?(attrs["notes"]) and optional_text?(attrs["terms"]) do
      record = struct(Invoice, Map.merge(values, %{business_id: business_id, customer_id: customer_id,
        currency: business.currency, due_date: due_date, accent_color_override: nil,
        notes: Map.get(attrs, "notes", business.invoice_notes), terms: Map.get(attrs, "terms", business.invoice_terms)}))
      {:ok, record}
    else
      _ -> {:error, :invalid_invoice}
    end
  end
  defp optional_text?(nil), do: true
  defp optional_text?(text) when is_binary(text), do: byte_size(text) <= 6000
  defp optional_text?(_), do: false
  def issue(key, invoice_id) do
    Repo.transaction(fn ->
      business = Repo.one!(from b in Business, where: b.id == ^key.business_id, lock: "FOR UPDATE")
      invoice = locked_invoice(key.business_id, invoice_id)
      if invoice.status != "draft", do: Repo.rollback(:already_issued)
      if not Billing.usage(business).can_issue, do: Repo.rollback(:subscription_required)
      sequence = business.invoice_sequence + 1
      Repo.update!(Ecto.Changeset.change(business, invoice_sequence: sequence))
      invoice = Repo.update!(Ecto.Changeset.change(invoice, status: "issued", issue_date: Date.utc_today(), business_snapshot: invoice_branding(business, invoice),
        customer_snapshot: customer_snapshot(invoice.customer_id, key.business_id), number: business.invoice_prefix <> String.pad_leading(to_string(sequence), 6, "0")))
      post_invoice(key, invoice)
      audit(key, "invoice.issued", invoice.id)
      invoice
    end)
  end

  def payment_methods, do: [{"Cash", "cash"}, {"M-Pesa", "mpesa"}, {"Bank transfer", "bank_transfer"}, {"Card", "card"}, {"Cheque", "cheque"}, {"Other", "other"}]
  def payment_label(method), do: Map.get(Map.new(payment_methods(), fn {label, value} -> {value, label} end), method, "Not recorded")
  def account_label(account), do: Map.get(%{"1000" => "Bank", "1010" => "Cash on hand", "1020" => "Mobile money", "1030" => "Card clearing", "1040" => "Cheques pending", "1090" => "Other receipts", "1100" => "Accounts receivable", "2100" => "Tax payable", "4000" => "Sales"}, account, account)

  def payment_values(attrs) do
    method = attrs["method"]
    notes = attrs["notes"] || ""
    with true <- method in Enum.map(payment_methods(), &elem(&1, 1)),
         {:ok, amount} <- Money.positive(attrs["amount"]),
         {:ok, date} <- parse_date(attrs["received_on"]),
         reference when is_binary(reference) and byte_size(reference) in 1..200 <- attrs["reference"],
         true <- String.trim(reference) != "",
         true <- is_binary(notes) and String.length(notes) <= 500 do
      {:ok, %{amount: amount, date: date, reference: String.trim(reference), method: method, notes: notes}}
    else
      _ -> {:error, :select_payment_method_and_check_amount_date_reference}
    end
  end

  def pay(key, invoice_id, attrs) do
    with {:ok, values} <- payment_values(attrs) do
      %{amount: amount, date: date, reference: reference, method: method, notes: notes} = values
      Repo.transaction(fn ->
        Repo.one!(from b in Business, where: b.id == ^key.business_id, lock: "FOR UPDATE")
        invoice = locked_invoice(key.business_id, invoice_id)
        case Repo.get_by(Payment, business_id: key.business_id, reference: reference) do
          %Payment{} = payment ->
            if payment.invoice_id != invoice.id or not Decimal.equal?(payment.amount, amount) or payment.received_on != date or payment.method != method or payment.notes != notes,
              do: Repo.rollback(:reference_conflict)
            payment
          nil ->
            if invoice.status != "issued", do: Repo.rollback(:invoice_not_payable)
            if Decimal.compare(amount, Decimal.sub(invoice.total, invoice.paid)) == :gt, do: Repo.rollback(:overpayment)
            payment = Repo.insert!(%Payment{business_id: key.business_id, invoice_id: invoice.id, amount: amount, reference: reference, received_on: date, method: method, notes: notes})
            paid = Decimal.add(invoice.paid, amount)
            Repo.update!(Ecto.Changeset.change(invoice, paid: paid, status: if(Decimal.equal?(paid, invoice.total), do: "paid", else: "issued")))
            account = Map.fetch!(%{"cash" => "1010", "mpesa" => "1020", "bank_transfer" => "1000", "card" => "1030", "cheque" => "1040", "other" => "1090"}, method)
            post(key, payment.id, "payment", date, account, "1100", amount)
            audit(key, "payment.recorded", payment.id)
            payment
        end
      end)
    end
  end

  def payment_history(business_id, invoice_id) do
    Repo.all(from p in Payment, where: p.business_id == ^business_id and p.invoice_id == ^invoice_id,
      order_by: [desc: p.received_on, desc: p.inserted_at])
  end

  def decorate_invoice(invoice, history) do
    latest = List.first(history)
    %{invoice | payment_count: length(history), last_payment_method: latest && latest.method, last_payment_date: latest && latest.received_on}
  end

  def ledger(business_id) do
    Repo.all(from j in Journal,
      left_join: p in Payment, on: j.kind == "payment" and p.id == j.source_id,
      left_join: i in Invoice, on: (j.kind == "invoice" and i.id == j.source_id) or i.id == p.invoice_id,
      where: j.business_id == ^business_id,
      order_by: [desc: j.inserted_at], limit: 200,
      select: %{id: j.id, kind: j.kind, date: j.posted_on, invoice_number: i.number,
        invoice_amount: i.total, payment_amount: p.amount, method: p.method, reference: p.reference})
    |> Enum.map(fn row -> Map.merge(row, %{label: if(row.kind == "invoice", do: "Invoice issued", else: "Payment received"),
      direction: if(row.kind == "payment", do: "Incoming", else: "Non-cash")}) end)
  end

  defp parse_date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp parse_date(_), do: {:error, :invalid_date}
  defp locked_invoice(business_id, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.one(from i in Invoice, where: i.business_id == ^business_id and i.id == ^uuid, lock: "FOR UPDATE") || Repo.rollback(:not_found)
      _ -> Repo.rollback(:not_found)
    end
  end

  defp invoice_branding(business, _invoice), do: Settings.snapshot(business)
  defp customer_snapshot(id, business_id) do
    customer = Repo.get_by!(Customer, id: id, business_id: business_id)
    Map.new([:name, :email, :address, :phone, :tax_id], fn field -> {Atom.to_string(field), Map.get(customer, field)} end)
  end
  defp post_invoice(key, invoice) do
    journal = Repo.insert!(%Journal{business_id: key.business_id, source_id: invoice.id, kind: "invoice", posted_on: invoice.issue_date})
    for {account, dr, cr} <- [{"1100", invoice.total, Decimal.new(0)}, {"4000", Decimal.new(0), invoice.subtotal}, {"2100", Decimal.new(0), invoice.tax_total}],
        Decimal.compare(Decimal.add(dr, cr), 0) == :gt do
      Repo.insert!(%Entry{business_id: key.business_id, journal_id: journal.id, account: account, debit: dr, credit: cr})
    end
  end
  defp post(key, source, kind, date, debit, credit, amount) do
    journal = Repo.insert!(%Journal{business_id: key.business_id, source_id: source, kind: kind, posted_on: date})
    for {account, dr, cr} <- [{debit, amount, Decimal.new(0)}, {credit, Decimal.new(0), amount}] do
      Repo.insert!(%Entry{business_id: key.business_id, journal_id: journal.id, account: account, debit: dr, credit: cr})
    end
  end
  defp audit(key, action, id), do: Repo.insert!(%Audit{business_id: key.business_id, api_key_id: key.id, user_id: Map.get(key, :user_id), action: action, record_id: id})
end
