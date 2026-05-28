# `Pdf.Reader.Encoding`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/encoding.ex#L1)

Encoding cascade facade for resolving PDF character codes to Unicode codepoints.

Spec reference: PDF 1.7 § 9.6.5 (Type1 encoding), § 9.10.3 (ToUnicode CMap).

## Cascade priority (highest first)

1. **ToUnicode CMap** — if a `%Pdf.Reader.CMap{}` is provided and the code is mapped,
   return that codepoint immediately.
2. **`/Differences` + AGL** — if a `/Differences` map is provided and has a glyph name
   for this byte, resolve the glyph name through the Adobe Glyph List.
3. **Base encoding** — one of `:win_ansi`, `:mac_roman`, or `:standard` (Standard Encoding).
4. **Unresolved fallback** — emit `{:unresolved, marker}` where `marker` is the glyph name
   (from /Differences) or `"byte:0xNN"` if no glyph name is available.

## `resolve_byte/3`

    resolve_byte(byte, cmap_or_nil, opts) :: {:ok, codepoint :: integer()} | {:unresolved, binary()}

Options:
- `:differences` — `%{integer() => glyph_name :: binary()}` or `nil`
- `:base_encoding` — `:win_ansi | :mac_roman | :standard | nil`

The caller substitutes `U+FFFD` for each `{:unresolved, _}` result and accumulates
unresolved entries for the `TextRun.unresolved` field (option B shape).

# `resolve_byte`

```elixir
@spec resolve_byte(0..255, Pdf.Reader.CMap.t() | nil, keyword()) ::
  {:ok, non_neg_integer()} | {:unresolved, binary()}
```

Resolves a single byte to a Unicode codepoint using the encoding cascade.

Returns `{:ok, codepoint}` on success or `{:unresolved, marker}` when no
mapping can be found. The marker is either a glyph name (if `/Differences`
provided one) or `"byte:0xNN"` for a raw byte with no name.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
