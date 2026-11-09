defmodule Waves.MixProject do
  use Mix.Project
  def project do
    [app: :waves, version: "0.5.0", elixir: "~> 1.17", elixirc_paths: elixirc_paths(Mix.env()),
     start_permanent: Mix.env() == :prod, deps: deps(), aliases: aliases()]
  end
  def application, do: [mod: {Waves.Application, []}, extra_applications: [:logger, :crypto, :eex]]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
  defp deps do
    [{:phoenix, "~> 1.8.0"}, {:bandit, "~> 1.5"}, {:phoenix_ecto, "~> 4.6"},
     {:ecto_sql, "~> 3.12"}, {:postgrex, ">= 0.0.0"}, {:jason, "~> 1.4"}, {:bcrypt_elixir, "~> 3.3"}, {:swoosh, "~> 1.17"}, {:gen_smtp, "~> 1.2"}, {:chromic_pdf, "~> 1.17.0"}, {:phoenix_live_view, "~> 1.1.0"}, {:phoenix_html, "~> 4.1"}, {:esbuild, "~> 0.10", runtime: Mix.env() == :dev}, {:lazy_html, ">= 0.0.0", only: :test}]
  end
  defp aliases do
    [setup: ["deps.get", "ecto.create", "ecto.migrate"],
     test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
     "assets.setup": ["esbuild.install --if-missing"], "assets.build": ["esbuild default"]]
  end
end
