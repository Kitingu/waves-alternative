import Config
config :waves, Waves.Repo, url: System.get_env("DATABASE_URL", "postgres://postgres:postgres@localhost/waves_dev"), show_sensitive_data_on_connection_error: false
config :waves, WavesWeb.Endpoint, http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: String.duplicate("local-development-only-", 4), server: true
config :waves, :bootstrap_login, false

config :waves, :dev_mailbox, true
