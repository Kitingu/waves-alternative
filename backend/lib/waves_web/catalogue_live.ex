defmodule WavesWeb.CatalogueLive do
  use Phoenix.LiveView, layout: false

  alias Waves.{Repo, Business, Catalogue, SimpleBilling}

  def mount(_, session, socket) do
    key = WavesWeb.BrowserAuth.scope(session)
    if key do
      {:ok, assign(socket, key: key, browser_session: session, business: Repo.get!(Business, key.business_id),
        items: Catalogue.list(key.business_id), item: %{}, editing: nil, show_form: false)}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event(event, params, socket) do
    if WavesWeb.BrowserAuth.scope(socket.assigns.browser_session),
      do: dispatch(event, params, socket),
      else: {:noreply, redirect(socket, to: "/login")}
  end

  defp dispatch("change", %{"item" => values}, socket),
    do: {:noreply, assign(socket, item: values)}

  defp dispatch("new", _, socket),
    do: {:noreply, assign(socket, item: %{}, editing: nil, show_form: true)}

  defp dispatch("cancel", _, socket),
    do: {:noreply, assign(socket, show_form: false, item: %{}, editing: nil)}

  defp dispatch("edit", %{"id" => id}, socket) do
    case Catalogue.get(socket.assigns.key.business_id, id) do
      nil -> {:noreply, put_flash(socket, :error, "Item not found.")}
      item ->
        defaults = SimpleBilling.defaults(item)
        values = %{"name" => item.name, "unit" => item.unit,
          "unit_price" => defaults["unit_price"], "uses_duration" => defaults["uses_duration"],
          "duration_unit" => defaults["duration_unit"], "default_notes" => defaults["notes"]}
        {:noreply, assign(socket, editing: id, item: values, show_form: true)}
    end
  end

  defp dispatch("toggle-active", %{"id" => id}, socket) do
    case Catalogue.get(socket.assigns.key.business_id, id) do
      nil -> {:noreply, put_flash(socket, :error, "Item not found.")}
      item -> finish(socket, Catalogue.save(socket.assigns.key.business_id, %{"is_active" => not item.is_active}, id))
    end
  end

  defp dispatch("save", %{"item" => values}, socket) do
    socket = assign(socket, item: values)
    finish(socket, Catalogue.save_simple(socket.assigns.key.business_id, values, socket.assigns.editing))
  end

  defp dispatch(_, _, socket), do: {:noreply, socket}

  defp finish(socket, {:ok, _}) do
    {:noreply, socket
      |> assign(item: %{}, editing: nil, show_form: false, items: Catalogue.list(socket.assigns.key.business_id))
      |> put_flash(:info, "Item saved.")}
  end

  defp finish(socket, {:error, %Ecto.Changeset{} = changeset}) do
    labels = %{name: "Name", unit: "Unit", unit_price: "Rate", duration_unit: "Duration unit", default_notes: "Notes"}
    message = Enum.map_join(changeset.errors, "; ", fn {field, {message, _}} ->
      "#{Map.get(labels, field, "Item")}: #{message}"
    end)
    {:noreply, put_flash(socket, :error, message)}
  end

  defp finish(socket, _), do: {:noreply, put_flash(socket, :error, "Item could not be saved.")}

  def render(assigns) do
    ~H"""
    <div class="shell">
      <aside><div class="brand">W / Finance</div><p class="business">{@business.name}</p>
        <nav><a href="/">Invoices & customers</a><a class="active" href="/catalogue">Saved items</a><a href="/settings">Business settings</a><a href="/businesses">Switch business</a><a href="/billing">Subscription</a></nav>
      </aside>
      <main>
        <header><div><p class="eyebrow">YOUR BUSINESS</p><h1>Saved items</h1><p class="muted">Save a name, unit and rate to reuse on invoices.</p></div><button class="primary" phx-click="new">Add item</button></header>
        <p :if={@flash["info"]} class="flash" role="status">{@flash["info"]}</p><p :if={@flash["error"]} class="error" role="alert">{@flash["error"]}</p>
        <section :if={@show_form}>
          <h2>{if @editing, do: "Edit item", else: "New item"}</h2>
          <form id="catalogue-form" phx-change="change" phx-submit="save">
            <div class="form-grid">
              <label>Item name<input name="item[name]" value={@item["name"]} required maxlength="200" placeholder="Microphone hire" /></label>
              <label>Unit<input name="item[unit]" value={Map.get(@item, "unit", "Units")} required maxlength="60" placeholder="Microphones, tours, hours…" /></label>
              <label>Rate ({@business.currency})<input name="item[unit_price]" value={@item["unit_price"]} required inputmode="decimal" /></label>
            </div>
            <label class="duration-check"><input type="hidden" name="item[uses_duration]" value="false" /><input type="checkbox" name="item[uses_duration]" value="true" checked={SimpleBilling.enabled?(@item["uses_duration"])} /> Charge by duration</label>
            <label :if={SimpleBilling.enabled?(@item["uses_duration"])} class="duration-default">Duration unit<input name="item[duration_unit]" value={Map.get(@item, "duration_unit", "Days")} required maxlength="60" placeholder="Days, nights, hours…" /></label>
            <details id="catalogue-notes" phx-hook="KeepOpen" class="line-notes"><summary>Notes (optional)</summary><textarea name="item[default_notes]" rows="2" maxlength="3000" placeholder="Details to include on the invoice">{@item["default_notes"]}</textarea></details>
            <div class="actions"><button type="button" phx-click="cancel">Cancel</button><button class="primary" phx-disable-with="Saving…">Save item</button></div>
          </form>
        </section>
        <section class="table-wrap">
          <table><thead><tr><th>Item</th><th>Unit</th><th class="numeric">Rate</th><th>Duration</th><th>Status</th><th></th></tr></thead>
            <tbody><tr :for={item <- @items}><td>{item.name}</td><td>{item.unit}</td><td class="numeric">{@business.currency} {Decimal.to_string(item.unit_price, :normal)}</td><td>{if SimpleBilling.enabled?(SimpleBilling.defaults(item)["uses_duration"]), do: SimpleBilling.defaults(item)["duration_unit"], else: "—"}</td><td>{if item.is_active, do: "Active", else: "Inactive"}</td><td><button phx-click="edit" phx-value-id={item.id}>Edit</button> <button phx-click="toggle-active" phx-value-id={item.id}>{if item.is_active, do: "Deactivate", else: "Activate"}</button></td></tr></tbody>
          </table>
          <p :if={@items == []} class="empty">No saved items yet. Add your first item, or create a one-off line on an invoice.</p>
        </section>
      </main>
    </div>
    """
  end
end
