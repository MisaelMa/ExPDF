# `Pdf.Reader.Utils`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/utils.ex#L1)

Shared utility helpers for `Pdf.Reader` sub-modules.

Provides string decoding and rectangle parsing used by AcroForm, Outlines,
Annotations, and Destination modules.

## Spec references

- PDF 1.7 § 7.9.2.2 — Text String Type (UTF-16BE BOM):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

# `decode_pdf_string`

```elixir
@spec decode_pdf_string(any()) :: String.t() | nil
```

Decodes a PDF string value to a UTF-8 `String.t()`.

Handles the following input variants:

- `nil` → `nil`
- non-binary, non-tuple → `nil`
- `{:string, binary}` tuple — unwraps and decodes the binary
- `<<0xFE, 0xFF, ...>>` — UTF-16BE BOM prefix → decoded to UTF-8 via `:unicode`
- plain binary — if valid UTF-8, returned as-is; otherwise best-effort ASCII
  extraction (non-ASCII bytes replaced with `"?"`)

## Spec reference

PDF 1.7 § 7.9.2.2 — Text String Type (UTF-16BE BOM).

# `parse_rect`

```elixir
@spec parse_rect(any()) :: {number(), number(), number(), number()} | nil
```

Parses a PDF `/Rect` array into a `{x1, y1, x2, y2}` tuple of floats.

Returns `nil` for any input that is not a 4-element list of numbers.

## Examples

    iex> Pdf.Reader.Utils.parse_rect([0, 0, 100, 200])
    {0.0, 0.0, 100.0, 200.0}

    iex> Pdf.Reader.Utils.parse_rect(nil)
    nil

---

*Consult [api-reference.md](api-reference.md) for complete listing*
