defmodule Waves.Application do
  use Application
  def start(_type, _args) do
    pdf_children = if Application.get_env(:waves, :pdf_enabled, true),
      do: [{ChromicPDF, Application.get_env(:waves, ChromicPDF, [])}], else: []
    Supervisor.start_link([Waves.Repo, WavesWeb.AuthThrottle, {Phoenix.PubSub, name: Waves.PubSub}] ++ pdf_children ++ [WavesWeb.Endpoint],
      strategy: :one_for_one, name: Waves.Supervisor)
  end
  def config_change(changed, _new, removed), do: WavesWeb.Endpoint.config_change(changed, removed)
end
