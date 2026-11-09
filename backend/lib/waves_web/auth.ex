defmodule WavesWeb.Auth do
  import Plug.Conn
  alias Waves.{Repo, ApiKey}
  def lookup(token) when is_binary(token) and byte_size(token) >= 32 do
    Repo.get_by(ApiKey, token_hash: Base.encode16(:crypto.hash(:sha256, token), case: :lower))
  end
  def lookup(_), do: nil
  def init(opts), do: opts
  def call(conn, _opts) do
    key = case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> lookup(token)
      _ -> nil
    end
    if key do
      assign(conn, :api_key, key)
    else
      conn |> put_resp_content_type("application/json") |> send_resp(401, Jason.encode!(%{error: %{code: "unauthorized", message: "A valid business API key is required."}})) |> halt()
    end
  end
end
