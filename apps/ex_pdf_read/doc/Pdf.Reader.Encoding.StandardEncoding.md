# `Pdf.Reader.Encoding.StandardEncoding`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/encoding/standard.ex#L1)

PDF Standard Encoding — byte-to-Unicode codepoint table.

Used for fonts that specify `/Encoding /StandardEncoding` (or omit
an explicit encoding and use a Type 1 font with default encoding).

The byte→glyph-name table is generated from `priv/standard_encoding.txt`
(PDF 1.7 ISO 32000-1, Annex D.2 Table D.2; cross-checked against
Mozilla pdf.js, Apache-2.0). Glyph names are resolved to Unicode
codepoints at compile time via the Adobe Glyph List
(`priv/glyphlist.txt`). Bytes that have no entry return `:undefined`.

# `decode`

```elixir
@spec decode(0..255) :: non_neg_integer() | :undefined
```

Decode a single byte to a Unicode codepoint.

Returns `:undefined` for bytes that have no mapping in PDF Standard Encoding.

# `entry_count`

```elixir
@spec entry_count() :: non_neg_integer()
```

Returns the number of byte→codepoint entries loaded at compile time.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
