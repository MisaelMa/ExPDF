# `Pdf.Reader.Outlines`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/outlines.ex#L1)

Walker for catalog `/Outlines` (PDF document outline / bookmarks tree).

Traverses the linked-list `/First`/`/Next` chain at each nesting level and
recurses into `/First` for child outlines. A `MapSet` of `{obj_num, gen_num}`
xref keys is threaded through the walk to prevent infinite loops when a
corrupt PDF has cyclic `/Next` or `/First` references. A depth cap of
`@max_outline_depth 32` ensures that arbitrarily deep trees do not overflow
the call stack.

## Spec references

- PDF 1.7 (ISO 32000-1) § 12.3.3 — Document Outline:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 12.3.2 — Destinations

# `read`

```elixir
@spec read(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Outline.t()], Pdf.Reader.Document.t()} | {:error, term()}
```

Reads the document outline tree from the PDF catalog's `/Outlines` entry.

Returns `{:ok, outlines, doc}` where `outlines` is a (possibly empty) list
of `%Pdf.Reader.Outline{}` structs arranged as a recursive tree.

When the catalog has no `/Outlines` key, returns `{:ok, [], doc}` — never
an error. The returned `doc` may have a warmer cache than the input (the
`:page_ref_index` and `:named_dest_index` cache keys may be populated).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
