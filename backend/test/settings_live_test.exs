defmodule WavesWeb.SettingsLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint WavesWeb.Endpoint
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Waves.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Waves.Repo, {:shared, self()})
    b = Waves.Repo.insert!(%Waves.Business{name: "Live settings", currency: "KES"})
    k = Waves.Repo.insert!(%Waves.ApiKey{business_id: b.id, name: "Live", token_hash: "settings-live"})
    %{conn: build_conn() |> Plug.Test.init_test_session(Waves.TestSession.for_business(k.business_id)), business: b}
  end
  test "saves company details and consumes a PNG upload", %{conn: conn, business: b} do
    {:ok, view, _} = live(conn, "/settings")
    path = Path.join(__DIR__, "fixtures/branding.png")
    logo = file_input(view, "#settings-form", :logo, [%{name: "logo.png", content: File.read!(path), type: "image/png"}])
    assert render_upload(logo, "logo.png") =~ "100%"
    view |> form("#settings-form", settings: %{name: "Updated business", tax_mode: "exclusive", tax_rate: "16"}) |> render_submit()
    saved = Waves.Repo.get!(Waves.Business, b.id)
    assert saved.name == "Updated business"
    assert saved.logo_data =~ "data:image/png;base64,"
    assert saved.tax_mode == "exclusive"
    assert render(view) =~ "Saved colour:"
    assert has_element?(view, "#saved-logo-preview img")
  end
end
