defmodule WavesWeb.LiveAccessTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint WavesWeb.Endpoint
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Waves.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Waves.Repo, {:shared, self()})
    :ok
  end
  test "browser redirects without a credential session" do
    assert {:error, {:redirect, %{to: "/login"}}} = live(build_conn(), "/")
  end
  test "business workspace renders and can add a customer" do
    b = Waves.Repo.insert!(%Waves.Business{name: "Live Test", currency: "KES"})
    k = Waves.Repo.insert!(%Waves.ApiKey{business_id: b.id, name: "Live", token_hash: "live-test"})
    conn = build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(k.business_id))
    {:ok, view, _} = live(conn, "/")
    view |> element("button", "Customers") |> render_click()
    view |> form("#customer-form", %{name: "New customer", email: "hello@example.com"}) |> render_submit()
    assert render(view) =~ "New customer"
  end
  test "API rejects missing credentials" do
    conn = get(build_conn(), "/api/v1/invoices")
    assert json_response(conn, 401)["error"]["code"] == "unauthorized"
  end
  test "a revoked session is rejected on an already connected socket" do
    b = Waves.Repo.insert!(%Waves.Business{name: "Revoked", currency: "KES"})
    session = Waves.TestSession.for_business(b.id)
    {:ok, view, _} = live(build_conn() |> Plug.Test.init_test_session(session), "/")
    Waves.Accounts.revoke_session(session["user_token"])
    render_click(view, "refresh", %{})
    assert_redirect(view, "/login")
  end
  test "legacy token browser sessions cannot access the workspace" do
    conn = build_conn() |> Plug.Test.init_test_session(%{"api_key_id" => Ecto.UUID.generate()})
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/")
  end

end
