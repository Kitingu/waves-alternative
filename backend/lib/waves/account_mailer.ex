defmodule Waves.Mailer do
  use Swoosh.Mailer, otp_app: :waves
end

defmodule Waves.AccountMailer do
  import Swoosh.Email
  require Logger

  def link(user, purpose, token) do
    title = if purpose == "verify", do: "Verify your email", else: "Reset your password"
    url = WavesWeb.Endpoint.url() <> "/" <> purpose <> "/" <> token
    message = new() |> to({user.name, user.email})
      |> from({"Waves Finance", Application.get_env(:waves, :mail_from, "accounts@example.com")})
      |> subject(title) |> text_body("#{title}\n\nOpen this link to continue:\n#{url}\n\nIf you did not request this, ignore this email.")
    case Waves.Mailer.deliver(message) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.error("Account email delivery failed: #{inspect(reason)}"); {:error, :email_delivery_failed}
    end
  end
end
