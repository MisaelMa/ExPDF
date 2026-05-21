# `Pdf.Reader.Page`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/page.ex#L1)

Page tree walker for `Pdf.Reader`.

Spec reference: PDF 1.7 § 7.7.3 (Page Tree), § 7.7.3.4 (Inheritance of Page Attributes).

## Page tree structure

The Catalog's `/Pages` entry points to the root of the page tree.
A node with `/Type /Pages` is an intermediate node containing a `/Kids`
array of refs to child nodes (either `/Pages` or `/Page`).
A node with `/Type /Page` is a leaf — one actual page.

## API

    list_refs(doc) :: {:ok, [ref], updated_doc} | {:error, reason}

Walks the tree recursively, collecting leaf `/Page` refs in document order.
Threads `doc` forward so that resolved objects accumulate in the cache.

## Catalog/Pages tree fallback (R-4)

When `doc.recover_mode` is `true` and the normal tree walk fails (missing
`/Root`, dangling `/Pages` ref, or other catalog resolution error), the
recovery branch scans the xref table directly for objects that match ALL of:

- `/Type /Page` in the object dict
- Either `/Contents` OR `/Parent` present (disambiguates from Form XObjects
  which also carry `/Type /XObject /Subtype /Form`)

The recovered list is in xref-insertion order, NOT document order. This
known limitation is by design — reconstruction from corrupt trees is
unreliable. A `{:page_tree_recovered, n}` event is appended to the
`recovery_log` so callers know page order may differ.

## Known limitations (R-4)

- **Page order loss** — catalog-fallback page order follows xref-insertion
  order, not the original document order. `/Parent` chain reconstruction is
  not attempted (unreliable on corrupt trees). The `{:page_tree_recovered, n}`
  event explicitly signals this to callers.

- **Encrypted AND corrupted PDFs** — when both the xref table and the catalog
  are corrupt, the R-3 linear scan reconstructs the xref but cannot include
  `/Encrypt` in the synthetic trailer. Without `/Encrypt`, decryption cannot
  proceed and the PDF is non-decryptable even with `recover: true`.

Spec citations:
- PDF 1.7 § 7.7.2 — Document catalog (Catalog dict, /Pages entry)
- PDF 1.7 § 7.7.3 — Page tree (/Pages /Kids traversal)
- PDF 1.7 § 7.7.3.4 — Inheritance of page attributes

# `list_refs`

```elixir
@spec list_refs(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Document.ref()], Pdf.Reader.Document.t()} | {:error, term()}
```

Walks the page tree and returns a list of leaf `/Page` object refs in order.

Returns `{:ok, refs, updated_doc}` where:
- `refs` is `[{obj_num, gen_num}]` in page order (or xref order in fallback)
- `updated_doc` has cache populated from the traversal

Returns `{:error, reason}` if the page tree cannot be traversed and
`recover_mode` is `false`.

When `recover_mode` is `true` and traversal fails, falls back to xref scan
and appends `{:page_tree_recovered, n}` to `recovery_log`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
