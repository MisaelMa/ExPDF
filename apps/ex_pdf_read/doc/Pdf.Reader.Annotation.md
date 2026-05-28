# `Pdf.Reader.Annotation`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/annotation.ex#L1)

Represents a single annotation extracted from a PDF page.

Annotations are page-attached objects that can represent comments, links,
highlights, file attachments, and many other interactive or markup elements.

This struct captures the common fields shared by all annotation subtypes plus
a `:kind_specific` map for subtype-specific data (e.g. `:quad_points` for
highlight/underline annotations).

## Spec references

- PDF 1.7 (ISO 32000-1) § 12.5 — Annotations:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 12.5.6.x — Annotation types (Link, Text, Highlight, Underline,
  StrikeOut, Squiggly, Square, Circle, FreeText, FileAttachment)

# `t`

```elixir
@type t() :: %Pdf.Reader.Annotation{
  contents: String.t() | nil,
  created: String.t() | nil,
  dest_page: pos_integer() | nil,
  embedded_file_ref: {pos_integer(), non_neg_integer()} | nil,
  kind_specific: map(),
  modified: String.t() | nil,
  page: pos_integer() | nil,
  rect: {number(), number(), number(), number()} | nil,
  subject: String.t() | nil,
  title: String.t() | nil,
  type: type(),
  url: String.t() | nil
}
```

# `type`

```elixir
@type type() ::
  :link
  | :text
  | :highlight
  | :underline
  | :strikeout
  | :squiggly
  | :square
  | :circle
  | :freetext
  | :file_attachment
  | :unknown
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
