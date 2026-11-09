import Config
config :waves, Waves.Repo, url: System.get_env("TEST_DATABASE_URL", "postgres://postgres:postgres@localhost/waves_test"), pool: Ecto.Adapters.SQL.Sandbox
config :waves, WavesWeb.Endpoint, server: false, secret_key_base: String.duplicate("test-only-", 8)
config :logger, level: :warning

config :waves, :pdf_enabled, false

config :bcrypt_elixir, :log_rounds, 4
config :waves, Waves.Mailer, adapter: Swoosh.Adapters.Test

config :waves, :auth_throttle, false
