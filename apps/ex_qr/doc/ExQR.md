# `ExQR`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_qr.ex#L1)

Pure Elixir QR code encoding library.

Supports versions 1–20, error correction levels L/M/Q/H,
and byte mode encoding. No external dependencies.

## Usage

    {:ok, matrix, size} = ExQR.encode("https://example.com")
    {:ok, matrix, size} = ExQR.encode("Hello", :h)

The matrix is a map of `{row, col} => 0 | 1` where 1 = black module.

## Converting to rows

    rows = ExQR.matrix_to_rows(matrix, size)
    # => [[0, 1, 1, ...], [1, 0, 0, ...], ...]

# `encode`

```elixir
@spec encode(String.t(), atom()) :: {:ok, map(), pos_integer()} | {:error, atom()}
```

Encode text into a QR code matrix.

## Parameters
  - `text` — the string to encode
  - `level` — error correction level: `:l`, `:m` (default), `:q`, or `:h`

## Returns
  `{:ok, matrix, size}` or `{:error, reason}`.

# `encode!`

Same as `encode/2` but raises on error.

# `matrix_to_rows`

Convert a QR matrix to a list of lists (row-major).

Returns `size` rows, each with `size` values (0 or 1).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
