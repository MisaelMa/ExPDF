defmodule ExPdfComponents.MixProject do
  use Mix.Project

  @version "2.0.0"
  @github_url "https://github.com/MisaelMa/ExPDF"

  def project do
    [
      app: :ex_pdf_components,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: "Reusable PDF components — Avatar, Badge, Card, Chip, Divider, Progress, Builder, StyledTable."
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_pdf_core, in_umbrella: true}
    ]
  end

  defp package do
    [
      maintainers: ["Misael Sánchez"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs),
      links: %{"GitHub" => @github_url}
    ]
  end
end
