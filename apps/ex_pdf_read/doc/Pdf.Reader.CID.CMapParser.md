# `Pdf.Reader.CID.CMapParser`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/cid/cmap_parser.ex#L1)

Minimal PostScript subset parser for Adobe predefined CMap files.

Handles only the operators required for CID lookup:
`begin/endcodespacerange`, `begin/endcidchar`, `begin/endcidrange`,
`begin/endnotdefchar`, `begin/endnotdefrange`, `usecmap`.

All other PostScript content (comments, /CMapName, /CIDSystemInfo,
/WMode, dict/array literals, dup/def/pop, etc.) is silently skipped.

Returns a parsed struct compatible with `Pdf.Reader.CID.PredefinedCMap`
for caching and lookup.

## Spec references

- PDF 1.7 (ISO 32000-1) § 9.7.5 — Predefined CMaps:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 9.7.6 — Codespace ranges:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- Adobe Tech Note #5099 — CMap and CIDFont Files Specification:
  https://adobe-type-tools.github.io/font-tech-notes/pdfs/5099.CMapResources.pdf
- Adobe Tech Note #5014 — CID-Keyed Font Technology Overview:
  https://adobe-type-tools.github.io/font-tech-notes/pdfs/5014.CIDFont_Spec.pdf

# `cmap`

```elixir
@type cmap() :: %{
  cidchar: %{required(non_neg_integer()) =&gt; non_neg_integer()},
  cidrange: [{non_neg_integer(), non_neg_integer(), non_neg_integer()}],
  notdef_chars: %{required(non_neg_integer()) =&gt; non_neg_integer()},
  notdef_ranges: [{non_neg_integer(), non_neg_integer(), non_neg_integer()}],
  codespaces: %{required(1..4) =&gt; [{non_neg_integer(), non_neg_integer()}]},
  parent: String.t() | nil
}
```

# `parse`

```elixir
@spec parse(text :: binary()) :: {:ok, cmap()} | {:error, term()}
```

Parse a PostScript CMap text and return a plain map with the extracted
CID mapping data.

Returns `{:ok, cmap_fields}` on success or `{:error, reason}` if the
input is fundamentally unparseable. Unknown or irrelevant tokens are
silently skipped — this function NEVER raises.

## Return map keys

- `:cidchar` — `%{code_integer => cid_integer}`
- `:cidrange` — `[{lo, hi, base_cid}]`
- `:notdef_chars` — `%{code_integer => cid_integer}`
- `:notdef_ranges` — `[{lo, hi, base_cid}]`
- `:codespaces` — `%{byte_length => [{lo, hi}]}`, grouped by byte width
- `:parent` — `String.t() | nil` — name from `usecmap` directive

---

*Consult [api-reference.md](api-reference.md) for complete listing*
