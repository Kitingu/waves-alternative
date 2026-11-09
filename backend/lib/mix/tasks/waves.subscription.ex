defmodule Mix.Tasks.Waves.Subscription do
  use Mix.Task
  @shortdoc "Activate a subscription after payment has been verified by the server administrator"

  def run(_) do
    Mix.Task.run("app.start")
    id = System.fetch_env!("SUBSCRIPTION_BUSINESS_ID")
    {:ok, expiry, _} = DateTime.from_iso8601(System.fetch_env!("SUBSCRIPTION_EXPIRES_AT"))
    if DateTime.compare(expiry, DateTime.utc_now()) != :gt, do: Mix.raise("Expiry must be in the future")
    business = Waves.Repo.get!(Waves.Business, id)
    business |> Ecto.Changeset.change(subscription_status: "active", subscription_expires_at: expiry) |> Waves.Repo.update!()
    Mix.shell().info("Subscription activated until the supplied expiry.")
  end
end
