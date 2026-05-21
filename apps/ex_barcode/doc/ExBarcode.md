# `ExBarcode`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_barcode.ex#L1)

Pure Elixir barcode encoding library.

Supports Code 128 (full ASCII). Returns bar patterns as lists of
module widths suitable for any renderer (PDF, SVG, Canvas, etc.).

## Standard encoding

    {:ok, bars} = ExBarcode.encode("Hello-123")

Returns alternating bar/space module widths.

## Shaped encoding (creative barcodes)

    {:ok, result} = ExBarcode.encode_shaped("DEMOCAMP", shape: :rv)
    result.bars          # positioned bars with individual heights
    result.decorations   # solid shapes (wheels, windows, etc.)

Returns an `ExBarcode.Shape.Result` with normalized 0.0–1.0 coordinates.
Any renderer scales to desired size.

Available shapes: `:rv`, `:camper`, `:city`, `:wave`, `:diamond`, `:hill`

# `available_shapes`

# `encode`

# `encode!`

# `encode_shaped`

# `encode_shaped!`

# `total_modules`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
