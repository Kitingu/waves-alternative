defmodule WavesWeb.FinanceLive do
  use Phoenix.LiveView, layout: false
  alias Waves.{Repo, Business, Finance, Catalogue}
  alias Waves.SimpleBilling
  def mount(_, session, socket) do
    key = WavesWeb.BrowserAuth.scope(session)
    if key do
      {:ok, socket |> assign(key: key, browser_session: session, business: Repo.get!(Business, key.business_id), tab: "Invoices", payment_id: nil, payment_form: %{}, pending_payment: nil, selected_invoice_id: nil, editing_id: nil, editing_version: nil, line_ids: [0], next_line_id: 1, draft_params: %{}) |> refresh()}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end
  # Revalidate the business credential on every event, including an already-connected socket.
  def handle_event(event, params, socket) do
    if WavesWeb.BrowserAuth.scope(socket.assigns.browser_session) do
      dispatch(event, params, socket)
    else
      {:noreply, redirect(socket, to: "/login")}
    end
  end
  defp dispatch("tab", %{"tab" => tab}, socket) when tab in ["Invoices", "Customers", "Ledger"],
    do: {:noreply, assign(socket, tab: tab, payment_id: nil)}
  defp dispatch("refresh", _, socket), do: {:noreply, refresh(socket)}
  defp dispatch("customer", params, socket), do: result(socket, Finance.customer(socket.assigns.key.business_id, params), "Customer added.")

  
  defp dispatch("invoice-change", params, socket) do
    params = case params["_target"] do
      ["lines", id, "item_id"] ->
        case Catalogue.get(socket.assigns.key.business_id, get_in(params, ["lines", id, "item_id"])) do
          %{is_active: true} = item ->
            line = SimpleBilling.defaults(item)
            notes = get_in(params, ["lines", id, "notes"])
            line = if is_binary(notes) and notes != "", do: Map.put(line, "notes", notes), else: line
            put_in(params, ["lines", id], line)
          _ -> params
        end
      _ -> params
    end
    {:noreply, assign(socket, draft_params: params)}
  end
  defp dispatch("toggle-duration", %{"line" => id}, socket) do
    {:noreply, update_line(socket, id, fn line ->
      line |> Map.put("uses_duration", not SimpleBilling.enabled?(line["uses_duration"]))
        |> Map.put_new("duration", "1") |> Map.put_new("duration_unit", "Days")
    end)}
  end
  defp dispatch("add-line", _, socket) do
    {:noreply, assign(socket, line_ids: socket.assigns.line_ids ++ [socket.assigns.next_line_id], next_line_id: socket.assigns.next_line_id + 1)}
  end
  defp dispatch("remove-line", %{"id" => id}, socket) do
    ids = Enum.reject(socket.assigns.line_ids, &(to_string(&1) == id))
    {:noreply, assign(socket, line_ids: if(ids == [], do: [socket.assigns.next_line_id], else: ids), next_line_id: socket.assigns.next_line_id + 1)}
  end
  defp dispatch("draft", params, socket) do
    lines = Enum.map(socket.assigns.line_ids, fn id ->
      line = get_in(params, ["lines", to_string(id)]) || %{}
      Map.put(line, "simple", true)
    end)
    attrs = Map.put(params, "lines", lines)

    response = if socket.assigns.editing_id do
      Finance.update_draft(socket.assigns.key, socket.assigns.editing_id, Map.put(attrs, "lock_version", socket.assigns.editing_version))
    else
      Finance.draft(socket.assigns.key.business_id, attrs)
    end
    case response do
      {:ok, _} -> result(reset_editor(socket), {:ok, nil}, "Draft saved.")
      error -> result(assign(socket, draft_params: params), error, "")
    end
  end
  defp dispatch("cancel-edit", _, socket), do: {:noreply, reset_editor(socket)}
  defp dispatch("edit-draft", %{"id" => id}, socket) do
    case Finance.invoice(socket.assigns.key.business_id, id) do
      %{status: "draft"} = invoice ->
        lines = invoice.lines |> Enum.with_index() |> Map.new(fn {line, index} -> {to_string(index), editable_line(line)} end)
        params = %{"customer_id" => invoice.customer_id, "due_date" => Date.to_iso8601(invoice.due_date),
          "tax_name" => invoice.tax_name, "tax_rate" => Decimal.to_string(invoice.tax_rate, :normal), "tax_mode" => invoice.tax_mode,
          "notes" => invoice.notes || "", "terms" => invoice.terms || "", "lines" => lines}
        {:noreply, socket |> assign(editing_id: id, editing_version: invoice.lock_version, draft_params: params,
          line_ids: Enum.to_list(0..(length(invoice.lines) - 1)), next_line_id: length(invoice.lines)) |> push_event("focus-editor", %{})}
      _ -> {:noreply, put_flash(socket, :error, "Only draft invoices can be edited.")}
    end
  end
  defp dispatch("issue", %{"id" => id}, socket), do: result(socket, Finance.issue(socket.assigns.key, id), "Invoice issued.")

  defp dispatch("show-payments", %{"id" => id}, socket) do
    if Finance.invoice(socket.assigns.key.business_id, id),
      do: {:noreply, assign(socket, selected_invoice_id: id)},
      else: {:noreply, put_flash(socket, :error, "Invoice not found.")}
  end
  defp dispatch("close-payments", _, socket), do: {:noreply, assign(socket, selected_invoice_id: nil)}
  defp dispatch("select-payment", %{"id" => id}, socket) do
    case Finance.invoice(socket.assigns.key.business_id, id) do
      %{status: "issued"} -> {:noreply, assign(socket, payment_id: id, payment_form: %{"received_on" => Date.to_iso8601(Date.utc_today())}, pending_payment: nil)}
      _ -> {:noreply, put_flash(socket, :error, "This invoice cannot accept a payment.")}
    end
  end
  defp dispatch("cancel-payment", _, socket), do: {:noreply, assign(socket, payment_id: nil, payment_form: %{}, pending_payment: nil)}
  defp dispatch("payment-change", attrs, socket), do: {:noreply, assign(socket, payment_form: attrs, pending_payment: nil)}
  defp dispatch("back-payment", _, socket), do: {:noreply, assign(socket, pending_payment: nil)}
  defp dispatch("review-payment", attrs, socket) do
    attrs = if attrs["method"] == "cash" and String.trim(attrs["reference"] || "") == "",
      do: Map.put(attrs, "reference", "CASH-" <> Ecto.UUID.generate()), else: attrs
    with %{status: "issued"} = invoice <- Finance.invoice(socket.assigns.key.business_id, socket.assigns.payment_id),
         {:ok, values} <- Finance.payment_values(attrs),
         true <- Decimal.compare(values.amount, Decimal.sub(invoice.total, invoice.paid)) != :gt do
      {:noreply, assign(socket, payment_form: attrs, pending_payment: attrs)}
    else
      _ -> {:noreply, socket |> assign(payment_form: attrs) |> put_flash(:error, "Select a method and check the amount, date and reference. The payment must not exceed the balance.")}
    end
  end
  defp dispatch("confirm-payment", _, %{assigns: %{pending_payment: attrs}} = socket) when is_map(attrs) do
    case Finance.pay(socket.assigns.key, socket.assigns.payment_id, attrs) do
      {:ok, _} -> result(assign(socket, pending_payment: nil, payment_form: %{}, selected_invoice_id: socket.assigns.payment_id), {:ok, nil}, "Payment recorded.")
      error -> result(socket, error, "")
    end
  end
  defp dispatch(_, _, socket), do: {:noreply, socket}
  defp result(socket, {:ok, _}, message), do: {:noreply, socket |> assign(payment_id: nil) |> put_flash(:info, message) |> refresh()}
  defp result(socket, {:error, reason}, _) do
    message = if is_atom(reason), do: reason |> Atom.to_string() |> String.replace("_", " "), else: "Please check the submitted fields."
    {:noreply, put_flash(socket, :error, message)}
  end
  defp refresh(socket) do
    id = socket.assigns.key.business_id
    assign(socket, business: Repo.get!(Business, id), customers: Finance.customers(id), invoices: Finance.invoices(id), entries: Finance.entries(id), ledger: Finance.ledger(id), usage: Waves.Billing.usage(Repo.get!(Business, id)), catalogue: Enum.filter(Catalogue.list(id), & &1.is_active))
  end


  defp reset_editor(socket) do
    assign(socket, editing_id: nil, editing_version: nil, draft_params: %{},
      line_ids: [socket.assigns.next_line_id], next_line_id: socket.assigns.next_line_id + 1)
  end

  defp editable_line(%{"simple" => true} = line), do: line
  defp editable_line(line) do
    item = %Waves.CatalogueItem{id: line["item_id"], name: line["description"], unit: line["unit"] || "Units",
      unit_price: Decimal.new(line["unit_price"]), billing_method: line["billing_method"] || "quantity", parameters: line["parameters"] || []}
    values = SimpleBilling.defaults(item)
    values = if item.billing_method == "quantity", do: Map.put(values, "quantity", line["quantity"]), else: values
    case Waves.BillingLine.normalize(values) do
      {:ok, normalized} ->
        if Decimal.equal?(Decimal.new(normalized["total"]), Decimal.new(line["total"])) do
          values
        else
          legacy_charge(line)
        end
      _ -> legacy_charge(line)
    end
  end
  defp legacy_charge(line) do
    %{"simple" => true, "item_id" => line["item_id"], "description" => line["description"],
      "quantity" => "1", "unit" => "Charge", "uses_duration" => false, "unit_price" => line["total"],
      "notes" => "Original calculation: " <> Waves.BillingLine.explanation(line) <> " at " <> line["unit_price"]}
  end
  defp selected_payments(assigns) do
    if assigns.selected_invoice_id, do: Finance.payment_history(assigns.key.business_id, assigns.selected_invoice_id), else: []
  end
  defp update_line(socket, id, fun) do
    lines = Map.get(socket.assigns.draft_params, "lines", %{})
    params = Map.put(socket.assigns.draft_params, "lines", Map.put(lines, id, fun.(Map.get(lines, id, %{}))))
    assign(socket, draft_params: params)
  end
  defp line_data(params, id), do: get_in(params, ["lines", to_string(id)]) || %{}
  defp calculated_line(params, id) do
    line = line_data(params, id)
    line = Map.put(line, "simple", true)
    case Waves.BillingLine.normalize(line) do
      {:ok, result} -> result["total"]
      _ -> "—"
    end
  end
  defp customer_name(customers, id), do: Enum.find_value(customers, id, fn c -> if c.id == id, do: c.name end)

  defp input(params, key, default \\ ""), do: Map.get(params, key, default)
  defp line_value(params, id, field, default \\ ""), do: get_in(params, ["lines", to_string(id), field]) || default
  defp money(value), do: value |> Decimal.round(2) |> Decimal.to_string(:normal)
  def render(assigns) do
    ~H"""
    <div class="shell">
      <aside>
        <div class="brand">W / Finance</div><p class="business">{@business.name}</p>
        <nav><button :for={tab <- ["Invoices", "Customers", "Ledger"]} phx-click="tab" phx-value-tab={tab} class={if @tab == tab, do: "active"}>{tab}</button><a href="/catalogue">Saved items</a><a href="/settings">Business settings</a><a href="/businesses">Switch business</a><a href="/billing">Subscription</a></nav>
        <p class="aside-note">Foundation release<br />Manual payments · {@business.currency}</p>
        <form method="post" action="/session"><input type="hidden" name="_method" value="delete" /><input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} /><button>Log out</button></form>
      </aside>
      <main>
        <header><div><p class="eyebrow">BUSINESS FINANCE</p><h1>{@tab}</h1><p class="muted">Your invoices, customers and accounting entries in one place.</p></div><button phx-click="refresh">Refresh</button></header>
        <p :if={@flash["info"]} role="status" class="flash">{@flash["info"]}</p><p :if={@flash["error"]} role="alert" class="error">{@flash["error"]}</p>
        <div :if={@tab == "Invoices"}>
          <div class="trial-banner"><span>{if @usage.active, do: "Active subscription", else: "#{@usage.remaining} of #{@usage.limit} free invoices remaining"}</span><a href="/billing">Subscription details</a></div>
          <section>
            <h2>{if @editing_id, do: "Edit draft invoice", else: "Create invoice"}</h2><p class="muted">Start with a draft. Issuing assigns its number and posts it to the ledger.</p>

            <form id="invoice-form" phx-change="invoice-change" phx-submit="draft">
              <div class="form-grid">
                <label>Customer<select name="customer_id" required><option value="">Select customer</option><option :for={c <- @customers} value={c.id} selected={input(@draft_params, "customer_id") == c.id}>{c.name}</option></select></label>
                <label>Due date<input name="due_date" type="date" required value={input(@draft_params, "due_date", Date.to_iso8601(Date.add(Date.utc_today(), @business.default_due_days)))} /></label>
              </div>


              <div class="simple-lines">
                <div class="simple-line-head"><span>Item</span><span>Qty</span><span>Unit</span><span>Duration</span><span>Rate</span><span class="numeric">Amount</span><span></span></div>
                <div :for={id <- @line_ids} class="simple-line-block" id={"invoice-line-#{id}"}>
                  <input type="hidden" name={"lines[#{id}][simple]"} value="true" />
                  <input type="hidden" name={"lines[#{id}][uses_duration]"} value={if SimpleBilling.enabled?(line_data(@draft_params, id)["uses_duration"]), do: "true", else: "false"} />
                  <div class="simple-line-row">
                    <div class="line-item-cell">
                      <label class="sr-only" for={"item-#{id}"}>Saved item</label>
                      <select id={"item-#{id}"} name={"lines[#{id}][item_id]"}><option value="">Choose saved item or type below</option><option :for={item <- @catalogue} value={item.id} selected={line_value(@draft_params, id, "item_id") == item.id}>{item.name}</option></select>
                      <input aria-label="Item description" name={"lines[#{id}][description]"} required maxlength="1000" value={line_value(@draft_params, id, "description")} placeholder="Item or service description" />
                    </div>
                    <input aria-label="Quantity" name={"lines[#{id}][quantity]"} required inputmode="decimal" value={line_value(@draft_params, id, "quantity", "1")} />
                    <input aria-label="Unit" name={"lines[#{id}][unit]"} required maxlength="60" value={line_value(@draft_params, id, "unit", "Units")} placeholder="Units" />
                    <div class="line-duration-cell">
                      <div :if={SimpleBilling.enabled?(line_data(@draft_params, id)["uses_duration"])} class="duration-values">
                        <input aria-label="Duration" name={"lines[#{id}][duration]"} required inputmode="decimal" value={line_value(@draft_params, id, "duration", "1")} />
                        <input aria-label="Duration unit" name={"lines[#{id}][duration_unit]"} required maxlength="60" value={line_value(@draft_params, id, "duration_unit", "Days")} />
                      </div>
                      <button type="button" class="text-button" phx-click="toggle-duration" phx-value-line={id}>{if SimpleBilling.enabled?(line_data(@draft_params, id)["uses_duration"]), do: "Remove duration", else: "+ Add duration"}</button>
                    </div>
                    <input aria-label="Rate" name={"lines[#{id}][unit_price]"} required inputmode="decimal" value={line_value(@draft_params, id, "unit_price")} placeholder="0.00" />
                    <strong class="line-amount">{calculated_line(@draft_params, id)}</strong>
                    <button :if={length(@line_ids) > 1} type="button" class="text-button" aria-label="Remove line" phx-click="remove-line" phx-value-id={id}>Remove</button>
                  </div>
                  <details id={"line-notes-#{id}"} phx-hook="KeepOpen" class="line-notes"><summary>Notes (optional)</summary><textarea aria-label="Line notes" name={"lines[#{id}][notes]"} rows="2" maxlength="3000" placeholder="Hire dates, venue or other details">{line_value(@draft_params, id, "notes")}</textarea></details>
                </div>
              </div>
              <button :if={length(@line_ids) < 100} type="button" phx-click="add-line">Add line</button>
              <details id="invoice-options" phx-hook="KeepOpen" class="invoice-options"><summary>Tax and invoice notes</summary>
              <div class="form-grid tax-fields">
                <label>Tax label<input name="tax_name" value={input(@draft_params, "tax_name", @business.tax_name)} required /></label>
                <label>Tax rate (%)<input name="tax_rate" inputmode="decimal" value={input(@draft_params, "tax_rate", Decimal.to_string(@business.tax_rate, :normal))} required /></label>
                <label>Tax treatment<select name="tax_mode"><option :for={{label, value} <- [{"No tax", "none"}, {"Add tax to prices", "exclusive"}, {"Prices include tax", "inclusive"}]} value={value} selected={input(@draft_params, "tax_mode", @business.tax_mode) == value}>{label}</option></select></label>
              </div>
              <div class="form-grid"><label>Customer note<textarea name="notes" rows="3">{input(@draft_params, "notes", @business.invoice_notes)}</textarea></label><label>Terms<textarea name="terms" rows="3">{input(@draft_params, "terms", @business.invoice_terms)}</textarea></label></div>
              </details>
              <div class="actions"><button class="primary" phx-disable-with="Saving…">{if @editing_id, do: "Save changes", else: "Save draft"}</button><button :if={@editing_id} type="button" phx-click="cancel-edit">Cancel edit</button></div>
            </form>

          </section>
          <section class="table-wrap">
            <p class="subtle">Latest 200 invoices</p>
            <table><thead><tr><th>Invoice</th><th>Customer</th><th>Due</th><th>Status</th><th class="numeric">Total</th><th class="numeric">Paid</th><th>Payments</th><th>Action</th></tr></thead><tbody><tr :for={i <- @invoices} id={"invoice-#{i.id}"}><td>{i.number || "Draft"}</td><td>{customer_name(@customers, i.customer_id)}</td><td>{i.due_date}</td><td><span class={"badge #{i.status}"}>{i.status}</span></td><td class="numeric">{@business.currency} {money(i.total)}</td><td class="numeric">{money(i.paid)}</td><td><button type="button" class="text-button" phx-click="show-payments" phx-value-id={i.id}>{i.payment_count || 0} payments</button><p :if={i.last_payment_date} class="subtle">{Finance.payment_label(i.last_payment_method)} · {i.last_payment_date}</p></td><td class="row-actions"><a class="button" href={"/invoices/#{i.id}"} target="_blank" rel="noopener">View</a><a class="button" href={"/invoices/#{i.id}/pdf"}>PDF</a><button :if={i.status == "draft"} phx-click="edit-draft" phx-value-id={i.id}>Edit</button><button :if={i.status == "draft"} disabled={!@usage.can_issue} phx-click="issue" phx-value-id={i.id} phx-disable-with="Issuing…">Issue</button><button :if={i.status == "issued"} phx-click="select-payment" phx-value-id={i.id}>Record payment</button><span :if={i.status == "paid"}>Settled</span></td></tr></tbody></table><p :if={@invoices == []} class="empty">Add a customer, then create your first invoice.</p>
          </section>

          <section :if={@selected_invoice_id} id="invoice-payments">
            <div class="toolbar"><h2>Invoice payment history</h2><button phx-click="close-payments">Close</button></div>
            <p class="muted">Each payment is recorded separately. The invoice shows the total paid and remaining balance.</p>
            <table><thead><tr><th>Date</th><th>Method</th><th>Reference</th><th class="numeric">Amount ({@business.currency})</th></tr></thead><tbody><tr :for={payment <- selected_payments(assigns)}><td>{payment.received_on}</td><td>{Finance.payment_label(payment.method)}</td><td>{payment.reference}</td><td class="numeric">{money(payment.amount)}</td></tr></tbody></table>
            <p :if={selected_payments(assigns) == []} class="empty">No payments recorded.</p>
          </section>
          <section :if={@payment_id} id="record-payment">
            <h2>Record payment</h2>
            <form :if={!@pending_payment} id="payment-form" phx-change="payment-change" phx-submit="review-payment">
              <div class="form-grid">
                <label>Amount ({@business.currency})<input name="amount" required inputmode="decimal" value={@payment_form["amount"]} /></label>
                <label>Payment method<select name="method" required><option value="">Select method</option><option :for={{label, value} <- Finance.payment_methods()} value={value} selected={@payment_form["method"] == value}>{label}</option></select></label>
                <label>Date received<input name="received_on" type="date" required value={@payment_form["received_on"]} /></label>
                <label>Reference<input name="reference" required={@payment_form["method"] != "cash"} value={@payment_form["reference"]} maxlength="200" placeholder={if @payment_form["method"] == "cash", do: "Optional for cash", else: "Transaction / bank reference"} /></label>
              </div>
              <label>Notes (optional)<textarea name="notes" maxlength="500" rows="2">{@payment_form["notes"]}</textarea></label>
              <div class="actions"><button type="button" phx-click="cancel-payment">Cancel</button><button class="primary">Review payment</button></div>
            </form>
            <div :if={@pending_payment} class="payment-review">
              <p class="eyebrow">CONFIRM PAYMENT</p><h3>{@business.currency} {@pending_payment["amount"]} · {Finance.payment_label(@pending_payment["method"])}</h3>
              <p>Received {@pending_payment["received_on"]}</p><p>Reference: {@pending_payment["reference"]}</p><p class="multiline">{@pending_payment["notes"]}</p>
              <div class="actions"><button type="button" phx-click="back-payment">Back</button><button class="primary" phx-click="confirm-payment" phx-disable-with="Recording…">Confirm & record</button></div>
            </div>
          </section>

        </div>
        <div :if={@tab == "Customers"}>
          <section><h2>Add customer</h2><form id="customer-form" phx-submit="customer"><div class="form-grid"><label>Name<input name="name" required maxlength="200" /></label><label>Email<input name="email" type="email" /></label><label>Phone<input name="phone" /></label><label>Tax registration / PIN<input name="tax_id" /></label><label>Billing address<textarea name="address" rows="2"></textarea></label></div><button class="primary" phx-disable-with="Saving…">Save customer</button></form></section>
          <section class="table-wrap"><table><thead><tr><th>Name</th><th>Email</th></tr></thead><tbody><tr :for={c <- @customers}><td>{c.name}</td><td>{c.email}</td></tr></tbody></table></section>
        </div>

        <section :if={@tab == "Ledger"} class="table-wrap">
          <h2>Transactions</h2><p class="muted">Incoming and outgoing show money movements. Issuing an unpaid invoice is a non-cash transaction.</p>
          <table><thead><tr><th>Date</th><th>Description</th><th>Invoice</th><th class="numeric">Incoming</th><th class="numeric">Outgoing</th><th>Method</th><th>Reference</th></tr></thead><tbody><tr :for={row <- @ledger}><td>{row.date}</td><td>{row.label}<span :if={row.direction == "Non-cash"} class="badge">Non-cash</span></td><td>{row.invoice_number}</td><td class="numeric">{if row.direction == "Incoming", do: money(row.payment_amount), else: "—"}</td><td class="numeric">{if row.direction == "Outgoing", do: money(row.payment_amount), else: "—"}</td><td>{if row.method, do: Finance.payment_label(row.method), else: "—"}</td><td>{row.reference}</td></tr></tbody></table>
          <details id="accounting-entries" phx-hook="KeepOpen" class="invoice-options"><summary>Accounting entries</summary><table><thead><tr><th>Journal</th><th>Account</th><th class="numeric">Debit</th><th class="numeric">Credit</th></tr></thead><tbody><tr :for={e <- @entries}><td>{String.slice(e.journal_id, 0, 8)}</td><td>{Finance.account_label(e.account)} ({e.account})</td><td class="numeric">{money(e.debit)}</td><td class="numeric">{money(e.credit)}</td></tr></tbody></table></details>
        </section>

      </main>
    </div>
    """
  end
end
