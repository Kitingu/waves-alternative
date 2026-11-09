alias Waves.{Repo, Business, ApiKey}
token = System.fetch_env!("BOOTSTRAP_API_KEY")
if byte_size(token) < 32, do: raise("BOOTSTRAP_API_KEY must contain at least 32 characters")
hash = Base.encode16(:crypto.hash(:sha256, token), case: :lower)
Repo.transaction(fn ->
  unless Repo.get_by(ApiKey, token_hash: hash) do
    business = Repo.insert!(%Business{name: System.get_env("BUSINESS_NAME", "My Business"), currency: "KES"})
    Repo.insert!(%ApiKey{business_id: business.id, name: "Bootstrap development access", token_hash: hash})
  end
end)
IO.puts("Business access is ready. The API key was not printed.")
