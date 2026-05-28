defmodule ExPdfCore.MixProject do
  use Mix.Project

  @version "1.0.2"
  @github_url "https://github.com/MisaelMa/ExPDF"

  def project do
    [
      app: :ex_pdf_core,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      package: package(),
      description: "Core PDF writer engine — document, page, export, fonts, layout primitives.",
      releaser: [publish: true]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger, :crypto, :inets, :ssl]]
  end

  defp deps do
    [
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
      files: ~w(lib mix.exs fonts README.md),
      links: %{"GitHub" => @github_url}
    ]
  end
end
