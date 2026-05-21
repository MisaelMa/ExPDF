# `Pdf.Reader.CID.CIDToGIDMap`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/cid/cid_to_gid.ex#L1)

Parser and lookup for the PDF `/CIDToGIDMap` entry in Type2 CIDFont dicts.

`/CIDToGIDMap` maps CIDs to GIDs (glyph indices) in the referenced CIDFont
program. This module parses it and stores the result for future glyph-rendering
work. It is NOT used in the Unicode resolution cascade — the cascade goes
CID → Unicode directly via the registry tables.

## Supported forms

- `{:name, "Identity"}` — GID == CID for all characters.
- `{:stream, dict, raw_bytes}` — FlateDecode-decoded binary of uint16-BE pairs.
- `{:ref, n, g}` — indirect reference resolved via `Pdf.Reader.ObjectResolver`.

## Spec references

- PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 9.7.4 — CIDFonts (/CIDToGIDMap key description)
- PDF 1.7 § 9.7.5 — Predefined CMaps (Identity-H/V context)

# `lookup`

```elixir
@spec lookup(:identity | {:stream_map, binary()}, non_neg_integer()) ::
  {:ok, non_neg_integer()} | :error
```

Look up a CID in a parsed CIDToGIDMap.

Returns `{:ok, gid}` or `:error`.

- `:identity` — GID == CID always.
- `{:stream_map, bytes}` — binary offset at `cid * 2`, decoded as big-endian uint16.

# `parse`

```elixir
@spec parse(any(), Pdf.Reader.Document.t()) ::
  {:ok, :identity | {:stream_map, binary()}, Pdf.Reader.Document.t()}
  | {:error, :malformed}
```

Parse a `/CIDToGIDMap` PDF value into an internal representation.

Returns:
- `{:ok, :identity, doc}` for `{:name, "Identity"}`
- `{:ok, {:stream_map, binary}, doc}` for stream values (decoded)
- `{:error, :malformed}` for unrecognised values

---

*Consult [api-reference.md](api-reference.md) for complete listing*
