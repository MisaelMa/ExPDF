# ExPDF

[![Hex.pm](https://img.shields.io/hexpm/v/ex_pdf.svg)](https://hex.pm/packages/ex_pdf)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_pdf)
[![License](https://img.shields.io/hexpm/l/ex_pdf.svg)](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md)

Native Elixir PDF **reader** and **writer**. Meta-package that includes
[`ex_pdf_core`](https://hex.pm/packages/ex_pdf_core),
[`ex_pdf_components`](https://hex.pm/packages/ex_pdf_components), and
[`ex_pdf_read`](https://hex.pm/packages/ex_pdf_read).

Uses only the Erlang/OTP standard library. **No Hex runtime dependencies,
no system tools.**

## Installation

```elixir
def deps do
  [
    {:ex_pdf, "~> 1.0"}
  ]
end
```

## Writing PDFs

```elixir
Pdf.build([size: :a4, compress: true], fn pdf ->
  pdf
  |> Pdf.set_font("Helvetica", 12)
  |> Pdf.text_at({200, 200}, "Hello, world!")
  |> Pdf.add_image({100, 100}, "logo.png")
end)
|> Pdf.export()
```

## Reading PDFs

```elixir
{:ok, doc} = Pdf.Reader.open("invoice.pdf")
{:ok, %Pdf.Reader.Result{} = result, _doc} = Pdf.Reader.read(doc)

result.meta.title       # "Invoice 042"
result.meta.page_count  # 3

for page <- result.pages, line <- page.lines, token <- line.tokens do
  IO.puts(token.text)
end
```

## Declarative templates (Builder)

```elixir
template = [
  %{type: :row, props: %{
    children: [
      {3, [%{type: :text, props: %{content: "Title", style: %{position: {0, -16}}}}]},
      {1, [%{type: :text, props: %{content: "Brand", style: %{position: {0, -16}}}}]}
    ],
    style: %{position: :cursor, size: {:full, 30}}
  }}
]

Pdf.Builder.render(template, config)
```

Auto-pagination included — page breaks are inserted automatically when
content overflows.

## Sub-packages

| Package | Description |
|---------|-------------|
| [`ex_pdf_core`](https://hex.pm/packages/ex_pdf_core) | Core writer engine — document, page, export, fonts, layout |
| [`ex_pdf_components`](https://hex.pm/packages/ex_pdf_components) | Reusable components — Avatar, Card, Builder, StyledTable, 20+ more |
| [`ex_pdf_read`](https://hex.pm/packages/ex_pdf_read) | PDF reader — text, images, links, metadata, encryption, AcroForm |
| [`ex_barcode`](https://hex.pm/packages/ex_barcode) | Pure Elixir Code 128 barcode encoding |
| [`ex_qr`](https://hex.pm/packages/ex_qr) | Pure Elixir QR code encoding |

## License

MIT. See [LICENSE.md](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md).
