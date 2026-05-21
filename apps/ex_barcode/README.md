# ExBarcode

[![Hex.pm](https://img.shields.io/hexpm/v/ex_barcode.svg)](https://hex.pm/packages/ex_barcode)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_barcode)
[![License](https://img.shields.io/hexpm/l/ex_barcode.svg)](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md)

Pure Elixir barcode encoding — Code 128 (full ASCII). No external
dependencies. Returns bar patterns as lists of module widths suitable for
any renderer (PDF, SVG, Canvas, etc.).

Part of the [ExPDF](https://hex.pm/packages/ex_pdf) umbrella.

## Installation

```elixir
def deps do
  [
    {:ex_barcode, "~> 0.1"}
  ]
end
```

## Usage

### Standard encoding

```elixir
{:ok, bars} = ExBarcode.encode("Hello-123")
# Returns alternating bar/space module widths
```

### Shaped encoding (creative barcodes)

```elixir
{:ok, result} = ExBarcode.encode_shaped("DEMOCAMP", shape: :rv)
result.bars          # positioned bars with individual heights
result.decorations   # solid shapes (wheels, windows, etc.)
```

Returns an `ExBarcode.Shape.Result` with normalized 0.0–1.0 coordinates.
Any renderer scales to desired size.

Available shapes: `:rv`, `:camper`, `:city`, `:wave`, `:diamond`, `:hill`

## License

MIT. See [LICENSE.md](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md).
