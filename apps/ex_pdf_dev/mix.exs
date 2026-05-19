defmodule ExPdfDev.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_pdf_dev,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      deps: deps(),
      # NOT published to hex
      package: false
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_pdf_core, in_umbrella: true},
      {:ex_pdf_components, in_umbrella: true},
      {:ex_pdf_read, in_umbrella: true},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"}
    ]
  end
end
