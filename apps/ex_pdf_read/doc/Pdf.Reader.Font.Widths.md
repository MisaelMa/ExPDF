# `Pdf.Reader.Font.Widths`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/font/widths.ex#L1)

Per-font glyph-width lookup for text advance computation.

Builds closures of type `(binary() -> [non_neg_integer()])` that return, for
a binary of raw font bytes, a list of glyph-space advance widths (one per
glyph code encoded in the binary).

## Simple fonts (Type1, TrueType)

Width lookup uses `/Widths`, `/FirstChar`, `/LastChar` from the font dict.
Out-of-range codes fall back to `/MissingWidth` from `/FontDescriptor`, or
`0` if absent. (§ 9.6.2.1, § 9.6.4)

### Standard-14 fallback

When `/Widths` is entirely absent — typical of Standard 14 Type 1 fonts
(Helvetica, Times-Roman, Courier, Symbol, ZapfDingbats and their styled
variants) — the spec (§ 9.6.2.2) requires the reader to use bundled AFM
metrics. We do not bundle AFMs (documented gap), so every glyph is
approximated as **500 units (~0.5 em)**, the rough average across the
Adobe Standard 14 AFM tables. This restores usable text positioning for
Standard-14-only PDFs (most government forms, RFCs, simple reports);
exact column alignment still requires AFM bundling.

Source: Adobe Font Metrics for the Core 14 — public domain via
https://github.com/adobe-type-tools/Adobe-Core-14-Font-AFM-Files (avg
glyph width across the 14 fonts ≈ 500 units).

## CIDFonts (Type0 → DescendantFonts[0])

Width lookup uses `/W` (Form A and Form B entries) and `/DW` (default: 1000).
(§ 9.7.4.3)

## Cache

Widths closures for fonts referenced via `{:ref, n, g}` are cached in
`Document.cache` under key `{:font_widths, {n, g}}`, mirroring the decoder
cache strategy of `Pdf.Reader.Font`.

## Spec references

- PDF 1.7 § 9.4.4  — Text advance formula (tx per glyph)
- PDF 1.7 § 9.6.2.1 — Simple font /Widths, /FirstChar, /LastChar
- PDF 1.7 § 9.6.4   — Font descriptor /MissingWidth
- PDF 1.7 § 9.7.4.3 — CIDFont /W and /DW arrays

# `widths_fn`

```elixir
@type widths_fn() :: (binary() -&gt; [non_neg_integer()])
```

# `build_widths_fn`

```elixir
@spec build_widths_fn(
  map() | {:ref, pos_integer(), non_neg_integer()},
  Pdf.Reader.Document.t()
) ::
  {:ok, widths_fn(), Pdf.Reader.Document.t()} | {:error, term()}
```

Build a widths closure for a font dict or indirect reference.

Returns `{:ok, widths_fn, updated_doc}`.

Spec: § 9.6.2.1 (simple fonts), § 9.7.4.3 (CIDFonts).

# `build_widths_for_resources`

```elixir
@spec build_widths_for_resources(map(), Pdf.Reader.Document.t()) ::
  {:ok, %{required(binary()) =&gt; widths_fn()}, Pdf.Reader.Document.t()}
  | {:error, term()}
```

Build widths closures for all fonts in a page's resources map.

Mirrors `Pdf.Reader.Font.build_decoders_for_resources/2`.
Returns `{:ok, %{font_name => widths_fn}, updated_doc}`.

When `doc.recover_mode` is `true`: on per-font widths failure, installs a
zero-width fallback (all glyphs advance 0) and continues. The font_skipped
event is already logged by `build_decoders_for_resources`; no duplicate event
is emitted here.

When `doc.recover_mode` is `false`: halts on first font widths failure
(unchanged strict behavior).

# `parse_w_array`

```elixir
@spec parse_w_array([term()]) :: %{required(non_neg_integer()) =&gt; non_neg_integer()}
```

Parse a CIDFont `/W` array into a `%{cid => width}` map.

Supports:
- Form A: `c [w1 w2 …]` — CID `c`, `c+1`, … each get successive widths
- Form B: `c1 c2 w` — all CIDs from `c1` to `c2` inclusive get width `w`

Both forms may be interleaved in the same array. (§ 9.7.4.3)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
