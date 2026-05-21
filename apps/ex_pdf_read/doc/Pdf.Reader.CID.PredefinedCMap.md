# `Pdf.Reader.CID.PredefinedCMap`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/cid/predefined_cmap.ex#L1)

Lazy loader and lookup for Adobe predefined CMaps bundled in `priv/cmap/`.

Parses on first use via `Pdf.Reader.CID.CMapParser`, caches the result in
`Document.cache` keyed `{:predefined_cmap, name}`. Handles `usecmap` chains
recursively with a visited MapSet to prevent cycles. Missing or non-bundled
parents fall back to an empty CMap per discovery #182 (the UCS2 abstract parent
files do not exist in the upstream repo).

## Merge semantics

Child mappings override parent mappings:
- `cidchar` — `Map.merge(parent, child)` (child wins on collision)
- `cidrange` — child list prepended to parent list (child scanned first)
- `codespaces` — unioned; child entries prepended per byte-length

## Spec references

- PDF 1.7 (ISO 32000-1) § 9.7.5 — Predefined CMaps:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 9.7.6 — Codespace ranges and tokenization:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- Adobe Tech Note #5099 — CMap and CIDFont Files Specification:
  https://adobe-type-tools.github.io/font-tech-notes/pdfs/5099.CMapResources.pdf
- Adobe Tech Note #5014 — CID-Keyed Font Technology Overview:
  https://adobe-type-tools.github.io/font-tech-notes/pdfs/5014.CIDFont_Spec.pdf

# `bundled?`

```elixir
@spec bundled?(String.t()) :: boolean()
```

Returns `true` if `name` is one of the 40 bundled predefined CMap names.
This is an O(1) MapSet lookup — no I/O at call time.

# `load_by_name`

```elixir
@spec load_by_name(String.t(), Pdf.Reader.Document.t()) ::
  {:ok, map(), Pdf.Reader.Document.t()} | {:error, term()}
```

Load a predefined CMap by name, using `doc.cache` as a parse cache.

On the first call for a given name, reads `priv/cmap/<name>`, parses it via
`CMapParser.parse/1`, resolves the `usecmap` parent chain (if any), merges
parent + child (child overrides), and stores the merged result in
`doc.cache[{:predefined_cmap, name}]`.

Subsequent calls for the same name with a doc that already holds the cached
result return immediately without re-parsing.

Returns:
- `{:ok, cmap_map, updated_doc}` on success
- `{:error, {:not_bundled, name}}` if `name` is not in the bundle
- `{:error, :cycle}` if a cyclic `usecmap` chain is detected

# `lookup`

```elixir
@spec lookup(map(), non_neg_integer()) :: {:ok, non_neg_integer()} | :error
```

Look up `code` in a merged predefined CMap (as returned by `load_by_name/2`).

Resolution order (per PDF 1.7 § 9.7.5):
1. `cidchar` exact match
2. `cidrange` list scan (first matching range wins)
3. `notdef_chars` exact match
4. `notdef_ranges` list scan
5. `:error` — code not in any mapping

Returns `{:ok, cid}` or `:error`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
