# `Pdf.Reader.CID.Decoder`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/cid/decoder.ex#L1)

CID font decoder for Type0/Identity-H and Identity-V composite fonts.

Returns a `decoder_fn()` closure with the same contract as the simple-font
decoder: `(binary() -> {String.t(), [{non_neg_integer(), binary()}]})`.

## Resolution cascade (per CID)

1. **ToUnicode CMap** — if the font has a `/ToUnicode` stream, its `bf_char`/
   `bf_range` entries are checked first (most specific).
2. **Adobe registry table** — `/CIDSystemInfo /Ordering` maps to one of the four
   bundled collection modules (`AdobeJapan1`, `AdobeCNS1`, `AdobeKorea1`,
   `AdobeGB1`). O(1) pattern-match dispatch.
3. **U+FFFD fallback** — unresolved CIDs yield `U+FFFD` plus a sentinel tuple
   `{idx, "cid:0xHHHH"}` appended to the unresolved list.

## `__test_cmap__` shortcut

For unit tests, a pre-parsed `%Pdf.Reader.CMap{}` can be injected by storing
it in the font dict under the key `"__test_cmap__"`. This bypasses stream
resolution. (Mirrors the same shortcut in `Pdf.Reader.Font`.)

## Width / advance computation

This module handles **character decoding only** (bytes → Unicode text). Glyph
advance widths (`/W` and `/DW` entries on the DescendantFonts[0] dict) are read
separately by `Pdf.Reader.Font.Widths` (§ 9.7.4.3). The two concerns are
intentionally kept in separate modules: decoding and advance computation are
independent of each other.

## Spec references

- PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 9.7.4 — CIDFonts
- PDF 1.7 § 9.7.4.3 — /W and /DW arrays (handled by `Pdf.Reader.Font.Widths`)
- PDF 1.7 § 9.7.5 — CMaps (Identity-H, Identity-V predefined)

# `decoder_fn`

```elixir
@type decoder_fn() :: (binary() -&gt; {String.t(), [{non_neg_integer(), binary()}]})
```

# `build`

```elixir
@spec build(map(), Pdf.Reader.Document.t()) ::
  {:ok, decoder_fn(), Pdf.Reader.Document.t()} | {:error, term()}
```

Build a CID decoder closure from a Type0 font dict.

`font_dict` is the top-level Type0 font dictionary (already resolved).
Reads `DescendantFonts`, `CIDSystemInfo`, `CIDToGIDMap`, and `ToUnicode`.

Returns `{:ok, decoder_fn, updated_doc}`.

# `build_predefined`

```elixir
@spec build_predefined(map(), Pdf.Reader.Document.t()) ::
  {:ok, decoder_fn(), Pdf.Reader.Document.t()} | {:error, term()}
```

Build a predefined CMap decoder closure from a Type0 font dict whose
`/Encoding` names a bundled predefined CMap (e.g. `UniJIS-UTF16-H`).

Resolution cascade per code token (PDF 1.7 § 9.7.5, D9):
1. **ToUnicode CMap** — if present, checked first (most specific).
2. **Predefined CMap** — `cidchar` → `cidrange` → `notdef` lookup.
3. **Adobe registry table** — CID → Unicode via AdobeJapan1/CNS1/Korea1/GB1.
4. **U+FFFD fallback** — unresolved codes yield `U+FFFD` + sentinel.

Returns `{:ok, decoder_fn, updated_doc}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
