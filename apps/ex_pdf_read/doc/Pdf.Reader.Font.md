# `Pdf.Reader.Font`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/font.ex#L1)

Per-font decoder construction for the encoding cascade.

A "decoder" is a closure `(binary -> {String.t(), [{non_neg_integer(), binary()}]})`
that maps raw font-code bytes to UTF-8 text plus a list of unresolved sentinels.

## Simple fonts (Type1, TrueType, etc.)

Cascade per byte (delegates to `Pdf.Reader.Encoding.resolve_byte/3`):
ToUnicode CMap → /Differences + AGL → base encoding → U+FFFD + sentinel.

## Composite fonts (Type0/Identity-H/V)

When `/Encoding` is `Identity-H` or `Identity-V`, the font is dispatched to
`Pdf.Reader.CID.Decoder.build/2`. The CID decoder consumes bytes in 2-byte
big-endian chunks and resolves via:
ToUnicode CMap → Adobe registry table (Japan1/CNS1/Korea1/GB1) → U+FFFD.

Non-Identity predefined CMaps (`UniJIS-UTF16-H`, `GBK-EUC-H`, etc.) are
also supported when bundled in `priv/cmap/` — the decoder dispatches to
`Pdf.Reader.CID.Decoder.build_predefined/2` which uses
`Pdf.Reader.CID.PredefinedCMap` for byte→CID lookup followed by the
same Adobe registry → Unicode resolution as Identity-H/V.

## Cache

Decoders for fonts referenced by indirect ref `{:ref, n, g}` are cached in
`Document.cache` under key `{:font_decoder, {n, g}}` for reuse across pages
with shared font resources. Inline font dicts (plain maps, no ref) are NOT
cached.

## Recovery mode (R-2)

When `doc.recover_mode` is `true` and a font dict fails to resolve or build,
`build_decoders_for_resources/2` installs a fallback U+FFFD identity decoder
for that font instead of returning `{:error, _}`. The fallback emits
`<<0xFFFD::utf8>>` per input byte, which guarantees `String.valid?/1` is
`true` on the resulting text. A `{:font_skipped, page_n, font_name, reason}`
event is logged to `doc.recovery_log` for each failed font. Fonts that build
successfully are NOT affected.

Spec: PDF 1.7 § 9.6 (font dictionaries), § 9.10 (text content extraction).

## Spec references
- PDF 1.7 § 9.6 — Type 1 Fonts:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 9.6.5, § 9.6.5.1 — Character Encoding, /Differences arrays
- PDF 1.7 § 9.7 — Composite Fonts (Type0, CIDFonts, CMaps)
- PDF 1.7 § 9.7.4 — CIDFonts
- PDF 1.7 § 9.7.5 — Predefined CMaps (Identity-H, Identity-V)
- PDF 1.7 § 9.10.3 — ToUnicode CMaps

# `decoder_fn`

```elixir
@type decoder_fn() :: (binary() -&gt; {String.t(), [{non_neg_integer(), binary()}]})
```

# `build_decoder`

```elixir
@spec build_decoder(
  map() | {:ref, pos_integer(), non_neg_integer()},
  Pdf.Reader.Document.t()
) ::
  {:ok, decoder_fn(), Pdf.Reader.Document.t()} | {:error, term()}
```

Build a decoder closure for a font.

Accepts either:
- A `font_dict` (plain map) — inline font, built directly without caching.
- A `{:ref, n, g}` tuple — indirect font reference; result is cached in
  `doc.cache` under `{:font_decoder, {n, g}}`.

Returns `{:ok, decoder_fn, updated_doc}`.

# `build_decoders_for_resources`

```elixir
@spec build_decoders_for_resources(map(), Pdf.Reader.Document.t()) ::
  {:ok, %{required(binary()) =&gt; decoder_fn()}, [{binary(), term()}],
   Pdf.Reader.Document.t()}
  | {:error, term()}
```

Build decoders for all fonts in a page's resources map.

Walks `resources["Font"]` (a map of font name → font dict or ref) and calls
`build_decoder/2` for each entry. Returns a map keyed by font name.

In strict mode (`doc.recover_mode == false`): returns `{:ok, decoders, [], doc}`
on success, or `{:error, reason}` on first font build failure (unchanged).

In recovery mode (`doc.recover_mode == true`): on per-font build failure,
installs a per-byte U+FFFD fallback decoder for that font name and appends
`{font_name, reason}` to the returned `font_failures` list. The page is NOT
aborted. The caller is responsible for converting failures to
`{:font_skipped, page_n, font_name, reason}` events and logging them.

Returns `{:ok, %{font_name => decoder_fn}, [{font_name, reason}], updated_doc}`.

## Spec references
- PDF 1.7 § 9.6 — Font dictionaries
- PDF 1.7 § 9.10 — Extraction of text content

---

*Consult [api-reference.md](api-reference.md) for complete listing*
