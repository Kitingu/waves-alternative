defmodule WavesWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :waves
  @session_options [store: :cookie, key: "_waves_session", signing_salt: "waves-browser-session",
    same_site: "Lax", http_only: true, secure: Application.compile_env(:waves, :secure_cookies, false), max_age: 30 * 86400]
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]], longpoll: false
  plug Plug.Static, at: "/", from: :waves, gzip: false, only: ~w(assets)
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["application/json"], json_decoder: Phoenix.json_library(), length: 1_000_000
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug WavesWeb.Router
end
