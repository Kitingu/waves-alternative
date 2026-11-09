defmodule Mix.Tasks.Waves.Owner do
  use Mix.Task
  @shortdoc "Create the first owner account for an existing business (server administrator only)"

  def run(_) do
    Mix.Task.run("app.start")
    business_id = System.fetch_env!("OWNER_BUSINESS_ID")
    attrs = %{"name" => System.fetch_env!("OWNER_NAME"), "email" => System.fetch_env!("OWNER_EMAIL"),
      "password" => System.fetch_env!("OWNER_PASSWORD"), "password_confirmation" => System.fetch_env!("OWNER_PASSWORD")}
    case Waves.Accounts.bootstrap_owner(business_id, attrs) do
      {:ok, _} -> Mix.shell().info("Owner created. Log in with your email and password.")
      {:error, reason} when is_atom(reason) -> Mix.raise("Owner setup failed: #{reason}")
      {:error, _} -> Mix.raise("Owner setup failed. Check the email and password (12+ characters, at most 72 bytes).")
    end
  end
end
