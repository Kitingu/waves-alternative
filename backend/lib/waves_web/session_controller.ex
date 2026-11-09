defmodule WavesWeb.SessionController do
  use Phoenix.Controller, formats: [:html]
  plug WavesWeb.AuthThrottle when action == :create
  import Plug.Conn
  alias Waves.{Accounts}
  alias WavesWeb.AccountController

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate(email, password) do
      {:ok, user} ->
        token = Accounts.issue_token(user, "session")
        conn = conn |> configure_session(renew: true) |> clear_session() |> put_session(:user_token, token)
        case Accounts.businesses(user) do
          [business | _] -> conn |> put_session(:business_id, business.id) |> redirect(to: "/")
          [] -> redirect(conn, to: "/onboarding")
        end
      {:error, :unconfirmed} -> AccountController.page(conn |> put_status(403), :notice, email: email)
      _ -> AccountController.page(conn |> put_status(422), :login, email: email, error: "Email or password is incorrect.")
    end
  end
  def create(conn, _), do: AccountController.page(conn |> put_status(422), :login, error: "Please enter your email and password.")

  def delete(conn, _) do
    Accounts.revoke_session(get_session(conn, :user_token))
    conn |> configure_session(drop: true) |> redirect(to: "/login")
  end
end
