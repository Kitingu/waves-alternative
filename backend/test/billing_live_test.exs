defmodule WavesWeb.BillingLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint WavesWeb.Endpoint
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Waves.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Waves.Repo, {:shared, self()})
    b = Waves.Repo.insert!(%Waves.Business{name: "Billing live", currency: "KES"})
    k = Waves.Repo.insert!(%Waves.ApiKey{business_id: b.id, name: "Live", token_hash: "billing-live"})
    {:ok, item} = Waves.Catalogue.save(b.id, %{"code" => "TOUR", "name" => "Tour", "unit_price" => "150", "billing_method" => "parameters", "parameters" => [%{"label" => "Days", "kind" => "multiplier", "value" => "3"}]})
    %{conn: build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(k.business_id)), item: item, business: b}
  end
  test "selecting an item populates only its invoice line", %{conn: conn, item: item, business: b} do
    {:ok, view, _} = live(conn, "/")
    html = render_change(view, "invoice-change", %{"_target" => ["lines", "0", "item_id"], "lines" => %{"0" => %{"item_id" => item.id}}})
    assert html =~ "450.00"
    assert has_element?(view, ~s(input[name="lines[0][duration]"][value="3"]))
    view |> element("button", "Add line") |> render_click()
    assert has_element?(view, ~s(input[name="lines[1][description]"][value=""]))
  end
  test "draft edits persist notes and payment review does not post until confirmed", %{conn: conn, business: b} do
    {:ok, c} = Waves.Finance.customer(b.id, %{"name" => "Buyer"})
    {:ok, draft} = Waves.Finance.draft(b.id, %{"customer_id" => c.id, "due_date" => "2026-12-31", "lines" => [%{"simple" => true, "description" => "Tour", "quantity" => "1", "unit_price" => "1000", "notes" => "Original"}]})
    {:ok, view, _} = live(conn, "/")
    render_click(view, "edit-draft", %{"id" => draft.id})
    assert has_element?(view, ~s(textarea[name="lines[0][notes]"]), "Original")
    render_submit(view, "draft", %{"customer_id" => c.id, "due_date" => "2026-12-31", "lines" => %{"0" => %{"description" => "Tour", "quantity" => "1", "unit_price" => "1000", "notes" => "Updated notes"}}})
    assert hd(Waves.Finance.invoice(b.id, draft.id).lines)["notes"] == "Updated notes"
    assert Waves.Repo.aggregate(Waves.Invoice, :count) == 1
    render_click(view, "issue", %{"id" => draft.id})
    render_click(view, "select-payment", %{"id" => draft.id})
    render_submit(view, "review-payment", %{"amount" => "200", "method" => "mpesa", "reference" => "MP-1", "received_on" => "2026-10-20"})
    assert Waves.Finance.payment_history(b.id, draft.id) == []
    assert render(view) =~ "Confirm &amp; record"
    render_click(view, "confirm-payment", %{})
    assert length(Waves.Finance.payment_history(b.id, draft.id)) == 1
    assert render(view) =~ "1 payments"
  end

end
