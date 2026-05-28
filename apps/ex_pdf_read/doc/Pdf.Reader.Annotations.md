# `Pdf.Reader.Annotations`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/annotations.ex#L1)

Walker for per-page `/Annots` arrays.

Iterates each page; resolves each annotation ref; dispatches by `/Subtype`
to type-specific extraction to build `%Pdf.Reader.Annotation{}` structs.

## Spec references

- PDF 1.7 (ISO 32000-1) § 12.5 — Annotations:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 12.5.6.x — Annotation types (Link, Text, Highlight, Underline,
  StrikeOut, Squiggly, Square, Circle, FreeText, FileAttachment)
- PDF 1.7 § 12.6 — Actions

# `read`

```elixir
@spec read(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Annotation.t()], Pdf.Reader.Document.t()} | {:error, term()}
```

Reads all annotations from all pages in the document.

Returns `{:ok, [Annotation.t()], doc}` where annotations are ordered
page-ascending. When no page has an `/Annots` array, returns `{:ok, [], doc}`.

The returned `doc` may have a warmer cache than the input.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
