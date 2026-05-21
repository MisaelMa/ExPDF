# ExPdfCore

[![Hex.pm](https://img.shields.io/hexpm/v/ex_pdf_core.svg)](https://hex.pm/packages/ex_pdf_core)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_pdf_core)
[![License](https://img.shields.io/hexpm/l/ex_pdf_core.svg)](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md)

Core PDF writer engine for Elixir — document, page, export, fonts, images,
graphics state, and layout primitives. Uses only the Erlang/OTP standard
library. No Hex runtime dependencies, no system tools.

Part of the [ExPDF](https://hex.pm/packages/ex_pdf) umbrella.

## Installation

```elixir
def deps do
  [
    {:ex_pdf_core, "~> 1.0"}
  ]
end
```

> Most users should depend on [`ex_pdf`](https://hex.pm/packages/ex_pdf)
> instead, which bundles core, components, and the reader.

## What's included

- **`Pdf`** — main API: build documents, add pages, draw text, images,
  shapes, and manage graphics state
- **`Pdf.Document`** — document structure, page tree, fonts, objects
- **`Pdf.Page`** — individual page content streams
- **`Pdf.Export`** — serialize to PDF binary
- **`Pdf.Layout`** — text measurement and wrapping
- **`Pdf.Font` / `Pdf.Fonts`** — built-in and external font handling
- **`Pdf.Component.Box`** — box with border, background, padding
- **`Pdf.Component.Row`** — horizontal column distribution by weight
- **`Pdf.Component.Column`** — vertical row stacking with fixed heights

## Usage

```elixir
Pdf.build([size: :a4, compress: true], fn pdf ->
  pdf
  |> Pdf.set_font("Helvetica", 12)
  |> Pdf.text_at({200, 200}, "Hello, world!")
  |> Pdf.add_image({100, 100}, "logo.png")
end)
|> Pdf.export()
```

## License

MIT. See [LICENSE.md](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md).
