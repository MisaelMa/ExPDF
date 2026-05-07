defmodule ExPdf.Mixfile do
  use Mix.Project

  @version "1.0.1"
  @github_url "https://github.com/MisaelMa/ExPDF"
  @upstream_url "https://github.com/andrewtimberlake/elixir-pdf"

  def project do
    [
      app: :ex_pdf,
      name: "ExPDF",
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      # Releaser config (https://hexdocs.pm/releaser/0.0.7) — single-project
      # layout: this mix.exs is the only app, publishable to Hex.
      releaser: [
        apps_root: ".",
        publish: true
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger, :xmerl, :crypto]]
  end

  defp deps do
    [
      # Code style
      {:credo, "~> 1.0", only: [:dev, :test]},

      # Docs
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      # Release automation: bumps @version, updates CHANGELOG, tags + publishes.
      # See https://hexdocs.pm/releaser/0.0.7.
      {:releaser, "~> 0.0.7", only: :dev, runtime: false},

      # Dev server for previewing PDFs
      {:plug_cowboy, "~> 2.7", only: :dev, runtime: false},
      {:jason, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      description:
        "Native Elixir PDF reader and writer. Writes PDFs from declarative " <>
          "page descriptions; reads PDFs (text, layout, links, images, metadata, " <>
          "encryption, AcroForm, outlines, annotations) using Erlang/OTP stdlib only — " <>
          "no Hex or system dependencies.",
      maintainers: ["Misael Sánchez"],
      contributors: ["Andrew Timberlake (original elixir-pdf)", "Misael Sánchez"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs README* CHANGELOG* LICENSE* fonts priv),
      links: %{
        "GitHub" => @github_url,
        "Forked from" => @upstream_url,
        "Changelog" => "#{@github_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"],
        "extra_doc/Tables.md": []
      ],
      main: "readme",
      source_url: @github_url,
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/ex_pdf",
      assets: %{"extra_doc/assets" => "assets"},
      formatters: ["html"],
      groups_for_modules: [
        Reader: [
          Pdf.Reader,
          Pdf.Reader.Document,
          Pdf.Reader.Result,
          Pdf.Reader.Result.Page,
          Pdf.Reader.Line,
          Pdf.Reader.Shape,
          Pdf.Reader.TextRun,
          Pdf.Reader.Image,
          Pdf.Reader.Annotation,
          Pdf.Reader.Outline,
          Pdf.Reader.FormField
        ],
        Writer: [
          Pdf,
          Pdf.Document,
          Pdf.Page,
          Pdf.Builder,
          Pdf.Layout,
          Pdf.Fonts,
          Pdf.StyledTable
        ]
      ]
    ]
  end
end
