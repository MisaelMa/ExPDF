# ExQR

[![Hex.pm](https://img.shields.io/hexpm/v/ex_qr.svg)](https://hex.pm/packages/ex_qr)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/ex_qr)
[![License](https://img.shields.io/hexpm/l/ex_qr.svg)](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md)

Pure Elixir QR code encoding — versions 1–20, error correction levels
L/M/Q/H, byte mode. No external dependencies.

Part of the [ExPDF](https://hex.pm/packages/ex_pdf) umbrella.

## Installation

```elixir
def deps do
  [
    {:ex_qr, "~> 0.1"}
  ]
end
```

## Usage

```elixir
{:ok, matrix, size} = ExQR.encode("https://example.com")
{:ok, matrix, size} = ExQR.encode("Hello", :h)
```

The matrix is a map of `{row, col} => 0 | 1` where `1` = black module.

### Converting to rows

```elixir
rows = ExQR.matrix_to_rows(matrix, size)
# => [[0, 1, 1, ...], [1, 0, 0, ...], ...]
```

### Error correction levels

- `:l` — Low (~7% recovery)
- `:m` — Medium (~15% recovery, default)
- `:q` — Quartile (~25% recovery)
- `:h` — High (~30% recovery)

## License

MIT. See [LICENSE.md](https://github.com/MisaelMa/ExPDF/blob/main/LICENSE.md).
