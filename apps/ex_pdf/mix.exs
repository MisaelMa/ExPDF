defmodule ExPdf.MixProject do
  use Mix.Project

  @version "1.0.4"
  @github_url "https://github.com/MisaelMa/ExPDF"

  def project do
    [
      app: :ex_pdf,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      deps: deps(),
      docs: docs(),
      package: package(),
      description:
        "Native Elixir PDF reader and writer. Meta-package that includes " <>
          "ex_pdf_core, ex_pdf_components, and ex_pdf_read.",
      releaser: [publish: true]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_pdf_core, in_umbrella: true},
      {:ex_pdf_components, in_umbrella: true},
      {:ex_pdf_read, in_umbrella: true}
    ]
  end

  defp package do
    [
      maintainers: ["Misael Sánchez"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs README* CHANGELOG* LICENSE*),
      links: %{"GitHub" => @github_url}
    ]
  end

  defp docs do
    [
      extras: [
        "../../CHANGELOG.md": [],
        "../../LICENSE.md": [title: "License"],
        "../../README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @github_url,
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/ex_pdf",
      formatters: ["html"],
      groups_for_modules: [
        Core: [Pdf, Pdf.Document, Pdf.Page, Pdf.Layout, Pdf.Fonts],
        Components: [
          Pdf.Component.Avatar, Pdf.Component.Badge, Pdf.Component.Box,
          Pdf.Component.Card, Pdf.Component.Chip, Pdf.Component.Column,
          Pdf.Component.Divider, Pdf.Component.Progress, Pdf.Component.Row,
          Pdf.Builder, Pdf.StyledTable
        ],
        Reader: [
          Pdf.Reader, Pdf.Reader.Document, Pdf.Reader.Result,
          Pdf.Reader.Result.Page, Pdf.Reader.Line, Pdf.Reader.Shape,
          Pdf.Reader.TextRun, Pdf.Reader.Image, Pdf.Reader.Annotation,
          Pdf.Reader.Outline, Pdf.Reader.FormField, Pdf.Reader.Wordlist
        ]
      ]
    ]
  end
end
