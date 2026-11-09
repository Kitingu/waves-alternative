defmodule Waves.AccountsTest do
  use ExUnit.Case, async: false
  alias Waves.{Accounts, Repo, Business}
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    attrs = %{"name" => "Owner", "email" => "OWNER@example.test", "password" => "long-password-123", "password_confirmation" => "long-password-123"}
    {:ok, user} = Accounts.registration(attrs)
    %{user: user}
  end
  test "email verification is required and tokens are one use", %{user: user} do
    assert user.email == "owner@example.test"
    assert {:error, :unconfirmed} = Accounts.authenticate(user.email, "long-password-123")
    token = Accounts.issue_token(user, "verify")
    assert {:ok, _} = Accounts.confirm(token)
    assert {:error, :expired_token} = Accounts.confirm(token)
    assert {:ok, _} = Accounts.authenticate(user.email, "long-password-123")
    assert {:error, :invalid_credentials} = Accounts.authenticate(user.email, "wrong-password")
  end
  test "password reset invalidates existing sessions and cannot be replayed", %{user: user} do
    {:ok, user} = Accounts.confirm(Accounts.issue_token(user, "verify"))
    session = Accounts.issue_token(user, "session")
    token = Accounts.issue_token(user, "reset")
    attrs = %{"password" => "replacement-password-123", "password_confirmation" => "replacement-password-123"}
    assert Accounts.user_for_session(session).id == user.id
    assert {:ok, _} = Accounts.reset_password(token, attrs)
    assert Accounts.user_for_session(session) == nil
    assert {:error, :expired_token} = Accounts.reset_password(token, attrs)
    assert {:ok, _} = Accounts.authenticate(user.email, attrs["password"])
  end
  test "onboarding grants access only to the created business", %{user: user} do
    other = Repo.insert!(%Business{name: "Other", currency: "KES"})
    assert {:ok, business} = Accounts.onboard(user, %{"name" => "Tours", "country" => "Kenya", "currency" => "USD"})
    assert Accounts.actor(user, business.id).role == "owner"
    assert Accounts.actor(user, other.id) == nil
    assert Accounts.actor(user, "invalid") == nil
    assert WavesWeb.BrowserAuth.scope(%{"api_key_id" => Ecto.UUID.generate()}) == nil
  end
end
