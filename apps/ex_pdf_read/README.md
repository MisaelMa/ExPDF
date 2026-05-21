# ExPdfRead

[![Hex.pm](https://img.shields.io/hexpm/v/ex_pdf_read.svg)](https://hex.pm/packages/ex_pdf_read)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_pdf_read)
[![License](https://img.shields.io/hexpm/l/ex_pdf_read.svg)](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md)

Native Elixir PDF reader — text extraction with positions, layout
reconstruction, links, images, metadata, encryption (RC4/AES-128/AES-256),
AcroForm fields, outlines, and annotations. Uses only the Erlang/OTP
standard library.

Part of the [ExPDF](https://hex.pm/packages/ex_pdf) umbrella.

## Installation

```elixir
def deps do
  [
    {:ex_pdf_read, "~> 1.0"}
  ]
end
```

> Most users should depend on [`ex_pdf`](https://hex.pm/packages/ex_pdf)
> instead, which bundles core, components, and the reader.

## Usage

```elixir
{:ok, doc} = Pdf.Reader.open("invoice.pdf")
{:ok, %Pdf.Reader.Result{} = result, _doc} = Pdf.Reader.read(doc)

result.meta.title       # "Invoice 042"
result.meta.page_count  # 3

for page <- result.pages do
  for line <- page.lines, token <- line.tokens do
    IO.puts(token.text)
  end
end
```

### Convenience shapes

```elixir
{:ok, pages, _} = Pdf.Reader.read(doc, shape: :text)    # [String.t()] per page
{:ok, shapes, _} = Pdf.Reader.read(doc, shape: :shapes) # [%Shape{}] flat
```

### Encrypted PDFs

```elixir
{:ok, doc} = Pdf.Reader.open("encrypted.pdf", password: "secret")
```

Supports Standard Security Handler V1–V5 (RC4-40, RC4-128, AES-128,
AES-256).

### Error recovery

```elixir
{:ok, doc} = Pdf.Reader.open(broken_bin, recover: true)
```

Recovers from corrupted xref tables, missing `%%EOF`, broken page-tree
links, dangling font refs, and truncated streams.

### Dictionary-based word split

```elixir
{:ok, result, _} = Pdf.Reader.read(doc, dictionary: :es)
```

Bundled Spanish frequency list (~50k words). Custom wordlists via
`MapSet`.

## License

MIT. See [LICENSE.md](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md).
