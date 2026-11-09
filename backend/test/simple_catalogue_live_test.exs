defmodule WavesWeb.SimpleCatalogueLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint WavesWeb.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Waves.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Waves.Repo, {:shared, self()})
    business = Waves.Repo.insert!(%Waves.Business{name: "Simple screen", currency: "KES"})
    key = Waves.Repo.insert!(%Waves.ApiKey{business_id: business.id, name: "Test", token_hash: "simple-live"})
    %{conn: build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(key.business_id))}
  end

  test "item creation only asks for simple defaults", %{conn: conn} do
    {:ok, view, _} = live(conn, "/catalogue")
    refute has_element?(view, "#catalogue-form")
    view |> element("button", "Add item") |> render_click()
    refute has_element?(view, ~s(input[name="item[code]"]))
    refute has_element?(view, ~s(select[name="item[billing_method]"]))
    view |> form("#catalogue-form", item: %{name: "Delivery", unit: "Charge", unit_price: "30.00"}) |> render_submit()
    assert render(view) =~ "Delivery"
    refute has_element?(view, "#catalogue-form")
  end
end
