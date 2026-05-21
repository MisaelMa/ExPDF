# ExPdfComponents

[![Hex.pm](https://img.shields.io/hexpm/v/ex_pdf_components.svg)](https://hex.pm/packages/ex_pdf_components)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_pdf_components)
[![License](https://img.shields.io/hexpm/l/ex_pdf_components.svg)](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md)

Reusable PDF components and a declarative template builder for Elixir.
Built on top of [`ex_pdf_core`](https://hex.pm/packages/ex_pdf_core).

Part of the [ExPDF](https://hex.pm/packages/ex_pdf) umbrella.

## Installation

```elixir
def deps do
  [
    {:ex_pdf_components, "~> 1.0"}
  ]
end
```

> Most users should depend on [`ex_pdf`](https://hex.pm/packages/ex_pdf)
> instead, which bundles core, components, and the reader.

## Components

| Component | Description |
|-----------|-------------|
| `Pdf.Builder` | Declarative template engine with cursor layout and auto-pagination |
| `Pdf.StyledTable` | Data tables with headers, styles, and column config |
| `Pdf.Component.Alert` | Alert/notification boxes |
| `Pdf.Component.Avatar` | Circular/rounded image avatars |
| `Pdf.Component.Badge` | Inline text badges |
| `Pdf.Component.Barcode` | Code 128 barcodes (via `ex_barcode`) |
| `Pdf.Component.Blockquote` | Styled quotation blocks |
| `Pdf.Component.Card` | Container with shadow, border, background |
| `Pdf.Component.Chart` | Basic chart rendering |
| `Pdf.Component.Chip` | Tag/chip labels |
| `Pdf.Component.CodeBlock` | Monospaced code blocks |
| `Pdf.Component.Divider` | Horizontal rule / separator |
| `Pdf.Component.Footnote` | Page footnotes |
| `Pdf.Component.KeyValue` | Label–value pair lists |
| `Pdf.Component.List` | Ordered/unordered lists |
| `Pdf.Component.Metric` | KPI / metric display |
| `Pdf.Component.PageHeader` | Page header with title and subtitle |
| `Pdf.Component.Paginator` | Page number footer |
| `Pdf.Component.Progress` | Progress bar |
| `Pdf.Component.QrCode` | QR codes (via `ex_qr`) |
| `Pdf.Component.Rating` | Star ratings |
| `Pdf.Component.Signature` | Signature block |
| `Pdf.Component.StatCard` | Statistics card |
| `Pdf.Component.StepIndicator` | Step/wizard indicator |
| `Pdf.Component.Timeline` | Timeline visualization |
| `Pdf.Component.Toc` | Table of contents |

## Builder example

```elixir
template = [
  %{type: :row, props: %{
    children: [
      {3, [%{type: :text, props: %{content: "Title", style: %{position: {0, -16}}}}]},
      {1, [%{type: :text, props: %{content: "Brand", style: %{position: {0, -16}}}}]}
    ],
    style: %{position: :cursor, size: {:full, 30}}
  }},
  %{type: :spacer, props: %{amount: 10}}
]

Pdf.Builder.render(template, config)
```

The Builder supports cursor-based layout with automatic pagination — when
content overflows the page, page breaks are inserted automatically.

## License

MIT. See [LICENSE.md](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md).
