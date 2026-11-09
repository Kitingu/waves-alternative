defmodule Waves.TestSession do
  def for_business(business_id) do
    user = Waves.Repo.insert!(%Waves.User{name: "Test owner", email: Ecto.UUID.generate() <> "@example.test",
      password_hash: Bcrypt.hash_pwd_salt("test-password-123"), confirmed_at: DateTime.utc_now()})
    Waves.Repo.insert!(%Waves.Membership{user_id: user.id, business_id: business_id, role: "owner"})
    %{"user_token" => Waves.Accounts.issue_token(user, "session"), "business_id" => business_id}
  end
end
