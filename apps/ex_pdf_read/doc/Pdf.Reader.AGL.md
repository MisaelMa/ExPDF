# `Pdf.Reader.AGL`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/agl.ex#L1)

Adobe Glyph List (AGL) — compile-time glyph name to Unicode codepoint lookup.

Bundled from the Adobe Glyph List 2.0 (2002), available at:
https://github.com/adobe-type-tools/agl-aglfn

Licensed under the BSD-style permissive license reproduced in the header of
`priv/glyphlist.txt`.

## Usage

    iex> Pdf.Reader.AGL.glyph_to_unicode("eacute")
    {:ok, 0x00E9}

    iex> Pdf.Reader.AGL.glyph_to_unicode("notaname")
    :error

## Notes

- Only the FIRST codepoint of multi-codepoint entries is returned (ligatures
  such as `fi` map to their decomposed form's first character). This is
  sufficient for single-glyph font-encoding lookups.
- All ~4500 entries are compiled to BEAM pattern-match clauses at build time
  for O(1) lookup performance during text extraction.

# `glyph_to_unicode`

```elixir
@spec glyph_to_unicode(binary()) :: {:ok, non_neg_integer()} | :error
```

Look up a PostScript glyph name and return its Unicode codepoint.

Returns `{:ok, codepoint}` for known names, `:error` for unknown ones.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
