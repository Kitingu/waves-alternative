defmodule WavesWeb.BrowserAuth do
  import Plug.Conn
  alias Waves.Accounts

  def user(session) do
    case Accounts.user_for_session(session["user_token"]) do
      %{confirmed_at: confirmed} = user when not is_nil(confirmed) -> user
      _ -> nil
    end
  end

  def scope(session) do
    if user = user(session), do: Accounts.actor(user, session["business_id"])
  end

  def owner?(%{role: "owner"}), do: true
  def owner?(_), do: false
  def session(conn), do: get_session(conn)
  def scope_conn(conn), do: conn |> session() |> scope()
end
