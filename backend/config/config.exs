import Config
config :waves, ecto_repos: [Waves.Repo]
config :waves, Waves.Repo, migration_primary_key: [name: :id, type: :binary_id], migration_foreign_key: [type: :binary_id]
config :waves, WavesWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [formats: [json: WavesWeb.ErrorJSON], layout: false],
  pubsub_server: Waves.PubSub
config :waves, WavesWeb.Endpoint, live_view: [signing_salt: "waves-live-view"]
config :esbuild, version: "0.25.0", default: [
  args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets),
  cd: Path.expand("../assets", __DIR__), env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}]
config :phoenix, :json_library, Jason
config :waves, ChromicPDF, on_demand: true, offline: true, disable_scripts: true
config :waves, Waves.Mailer, adapter: Swoosh.Adapters.Local
config :swoosh, :api_client, false
import_config "#{config_env()}.exs"
