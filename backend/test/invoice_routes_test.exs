defmodule WavesWeb.InvoiceRoutesTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint WavesWeb.Endpoint
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Waves.Repo)
    a = Waves.Repo.insert!(%Waves.Business{name: "A", currency: "KES"})
    b = Waves.Repo.insert!(%Waves.Business{name: "B", currency: "KES"})
    key = Waves.Repo.insert!(%Waves.ApiKey{business_id: a.id, name: "A", token_hash: "routes-a"})
    foreign = Waves.Repo.insert!(%Waves.ApiKey{business_id: b.id, name: "B", token_hash: "routes-b"})
    {:ok, c} = Waves.Finance.customer(a.id, %{"name" => "Buyer"})
    {:ok, invoice} = Waves.Finance.draft(a.id, %{"customer_id" => c.id, "due_date" => "2026-12-31", "lines" => [%{"description" => "Service", "quantity" => "1", "unit_price" => "10"}]})
    %{key: key, foreign: foreign, invoice: invoice}
  end
  test "preview and download enforce business ownership", %{foreign: foreign, invoice: invoice} do
    for path <- ["/invoices/#{invoice.id}", "/invoices/#{invoice.id}/pdf"] do
      conn = build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(foreign.business_id)) |> get(path)
      assert conn.status == 404
    end
  end
  test "preview renders and disabled PDF renderer returns a useful response", %{key: key, invoice: invoice} do
    conn = build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(key.business_id)) |> get("/invoices/#{invoice.id}")
    assert html_response(conn, 200) =~ "Draft"
    conn = build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(key.business_id)) |> get("/invoices/#{invoice.id}/pdf")
    assert html_response(conn, 503) =~ "Print / Save as PDF"
  end
end
