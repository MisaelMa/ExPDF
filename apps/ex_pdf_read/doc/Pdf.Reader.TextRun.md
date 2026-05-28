# `Pdf.Reader.TextRun`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/text_run.ex#L1)

Struct representing a single text run extracted from a PDF page.

A text run corresponds to one `Tj` or `TJ` operator in the page's content
stream. Coordinates `(x, y)` are absolute user-space points computed by
multiplying the current text matrix by the current transformation matrix.

`:text` is always a valid UTF-8 `String.t()`. Glyphs that could not be
resolved to a Unicode codepoint are substituted with `U+FFFD` (REPLACEMENT
CHARACTER) and their original glyph information is recorded in `:unresolved`.

`:unresolved` is empty (`[]`) on the happy path. Each entry is a
`{codepoint_index, glyph_name}` pair locating the substitution within
`:text`.

# `t`

```elixir
@type t() :: %Pdf.Reader.TextRun{
  font: nil | binary(),
  page: pos_integer(),
  size: float(),
  text: String.t(),
  unresolved: [{non_neg_integer(), binary()}],
  x: float(),
  y: float()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
