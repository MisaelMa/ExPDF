# `Pdf.Reader.AcroForm`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/acroform.ex#L1)

AcroForm field walker for `Pdf.Reader`.

Extracts interactive form fields from a PDF's AcroForm field tree, returning
a flat list of leaf `%Pdf.Reader.FormField{}` structs with decoded names, types,
values, flags, and rectangles.

## Spec references

- PDF 1.7 (ISO 32000-1) § 12.7 — Interactive Forms:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- § 12.7.3 — Field Dictionaries
- § 12.7.3.1 — Field Flags
- § 12.7.4 — Field Types

# `read`

```elixir
@spec read(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.FormField.t()], Pdf.Reader.Document.t()} | {:error, term()}
```

Reads all AcroForm leaf fields from a document.

Returns `{:ok, [FormField.t()], Document.t()}` with a flat list of leaf fields.
When no `/AcroForm` is present, or `/Fields` is empty, returns `{:ok, [], doc}`.
Never returns `{:error, _}` for absent or empty AcroForms.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
