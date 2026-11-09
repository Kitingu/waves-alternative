defmodule WavesWeb.AccountController do
  use Phoenix.Controller, formats: [:html]
  plug WavesWeb.AuthThrottle when action in [:create_account, :send_verification, :send_reset, :reset, :create_business]
  import Plug.Conn
  alias Waves.{Accounts, Billing, Repo, Business}
  alias WavesWeb.{AccountPage, BrowserAuth}

  def login(conn, _), do: page(conn, :login)
  def register(conn, _), do: page(conn, :register)
  def forgot(conn, _), do: page(conn, :forgot)
  def reset_form(conn, %{"token" => token}), do: page(conn, :reset, token: token)
  def verify_form(conn, %{"token" => token}), do: page(conn, :verify, token: token)
  def legacy(conn, _), do: redirect(conn, to: "/login")

  def create_account(conn, attrs) do
    case Accounts.registration(attrs) do
      {:ok, user} ->
        case Accounts.send_link(user.email, "verify") do
          {:error, _} -> page(conn, :notice, email: user.email, error: "Your account was created, but email delivery failed. Please try resending.")
          _ -> page(conn, :notice, email: user.email)
        end
      {:error, _} -> page(conn |> put_status(422), :register, email: attrs["email"], error: "Check your details, matching passwords (12–72 bytes), or try logging in if you already have an account.")
    end
  end

  def send_verification(conn, attrs) do
    Accounts.send_link(attrs["email"], "verify")
    page(conn, :notice, email: attrs["email"])
  end

  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm(token) do
      {:ok, _} -> page(conn, :login, notice: "Email verified. You can now log in.")
      _ -> page(conn |> put_status(422), :notice, error: "This link has expired or was already used. Request another link.")
    end
  end

  def send_reset(conn, attrs) do
    Accounts.send_link(attrs["email"], "reset")
    page(conn, :login, notice: "If an account matches that address, a password reset link has been sent.")
  end

  def reset(conn, %{"token" => token} = attrs) do
    case Accounts.reset_password(token, attrs) do
      {:ok, _} -> conn |> configure_session(renew: true) |> clear_session() |> page(:login, notice: "Password updated. Please log in again.")
      _ -> page(conn |> put_status(422), :reset, token: token, error: "Check your passwords (12–72 bytes). If the link expired, request another reset.")
    end
  end

  def onboarding(conn, _) do
    if BrowserAuth.user(get_session(conn)), do: page(conn, :onboard), else: redirect(conn, to: "/login")
  end

  def create_business(conn, attrs) do
    if user = BrowserAuth.user(get_session(conn)) do
      case Accounts.onboard(user, attrs) do
        {:ok, business} -> conn |> put_session(:business_id, business.id) |> redirect(to: "/")
        _ -> page(conn |> put_status(422), :onboard, error: "Check the business name, country, currency and tax rate.")
      end
    else
      redirect(conn, to: "/login")
    end
  end

  def businesses(conn, _) do
    if user = BrowserAuth.user(get_session(conn)),
      do: page(conn, :businesses, businesses: Accounts.businesses(user)), else: redirect(conn, to: "/login")
  end

  def switch(conn, %{"business_id" => id}) do
    with user when not is_nil(user) <- BrowserAuth.user(get_session(conn)),
         actor when not is_nil(actor) <- Accounts.actor(user, id) do
      conn |> configure_session(renew: true) |> put_session(:business_id, actor.business_id) |> redirect(to: "/")
    else
      _ -> send_resp(conn, 403, "Business access denied")
    end
  end

  def billing(conn, _) do
    if actor = BrowserAuth.scope_conn(conn) do
      business = Repo.get!(Business, actor.business_id)
      page(conn, :billing, business: business, usage: Billing.usage(business), support: Application.get_env(:waves, :billing_support_email))
    else
      redirect(conn, to: "/login")
    end
  end

  def page(conn, mode, extras \\ []) do
    {title, description, action} = case mode do
      :login -> {"Welcome back", "Log in to manage your business finances.", "/session"}
      :register -> {"Create your account", "Start with five free invoices. No card required.", "/register"}
      :forgot -> {"Reset your password", "We will email you a secure reset link.", "/forgot-password"}
      :reset -> {"Choose a new password", "Use at least 12 characters.", "/reset/#{Keyword.get(extras, :token, "")}"}
      :verify -> {"Verify your email", "Confirm your email address to finish creating your account.", ""}
      :notice -> {"Check your email", "Open your verification email to continue.", ""}
      :onboard -> {"Set up your business", "Just the essentials. Branding can wait until later.", ""}
      :businesses -> {"Your businesses", "Choose the business you want to open.", ""}
      :billing -> {"Your subscription", "Your invoice allowance and subscription status.", ""}
    end
    html(conn, AccountPage.html(Map.merge(%{page: mode, title: title, description: description, action: action}, Map.new(extras))))
  end
end
