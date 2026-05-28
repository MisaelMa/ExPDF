defmodule ExPdfRead.MixProject do
  use Mix.Project

  @version "1.0.2"
  @github_url "https://github.com/MisaelMa/ExPDF"

  def project do
    [
      app: :ex_pdf_read,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      deps: deps(),
      docs: docs(),
      package: package(),
      description: "PDF reader — text extraction, layout, links, images, metadata, encryption, AcroForm.",
      releaser: [publish: true]
    ]
  end

  def application do
    [extra_applications: [:logger, :xmerl, :crypto]]
  end

  defp deps do
    [
      {:ex_pdf_core, in_umbrella: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @github_url,
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Misael Sánchez"],
      licenses: ["MIT"],
      files: ~w(lib priv mix.exs README.md),
      links: %{"GitHub" => @github_url}
    ]
  end
end
