import Config
if config_env() == :prod do
  config :waves, Waves.Repo, url: System.fetch_env!("DATABASE_URL"), pool_size: 10
  config :waves, WavesWeb.Endpoint, server: true,
    url: [host: System.fetch_env!("PHX_HOST"), port: 443, scheme: "https"],
    http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end

if chrome = System.get_env("CHROME_EXECUTABLE") do
  config :waves, ChromicPDF, chrome_executable: chrome
end

if config_env() == :prod do
  config :waves, :mail_from, System.fetch_env!("MAIL_FROM")
  config :waves, Waves.Mailer, adapter: Swoosh.Adapters.SMTP,
    relay: System.fetch_env!("SMTP_HOST"), port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    username: System.fetch_env!("SMTP_USERNAME"), password: System.fetch_env!("SMTP_PASSWORD"),
    tls: :always, auth: :always
end
config :waves, :billing_support_email, System.get_env("BILLING_SUPPORT_EMAIL")
