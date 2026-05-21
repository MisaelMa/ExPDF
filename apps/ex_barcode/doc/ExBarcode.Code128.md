# `ExBarcode.Code128`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_barcode/code128.ex#L1)

Code 128 barcode encoder.

Encodes a string into a list of bar widths suitable for rendering.
Supports Code 128B (full ASCII) with automatic Code C optimization
for runs of digit pairs.

## Reference

Code 128 uses three character sets (A, B, C). This implementation
primarily uses Code B (covers ASCII 32–127) with automatic switching
to Code C for efficient encoding of digit pairs.

# `encode`

```elixir
@spec encode(String.t()) :: {:ok, [integer()]} | {:error, atom()}
```

Encode a string into Code 128 bar pattern.

Returns `{:ok, bars}` where `bars` is a flat list of integers
representing alternating bar and space widths (starting with a bar).

Returns `{:error, reason}` if the input contains unsupported characters.

# `encode!`

Same as `encode/1` but raises on error.

# `total_modules`

Calculate the total width in modules (unit bar widths) for a given text.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
