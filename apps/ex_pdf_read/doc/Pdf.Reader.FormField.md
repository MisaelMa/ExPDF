# `Pdf.Reader.FormField`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/form_field.ex#L1)

Represents a single interactive form field extracted from a PDF AcroForm.

## Spec references

- PDF 1.7 (ISO 32000-1) § 12.7.4 — Field Types:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- § 12.7.3.1 — Field Flags

# `field_type`

```elixir
@type field_type() :: :text | :button | :choice | :signature | :unknown
```

# `t`

```elixir
@type t() :: %Pdf.Reader.FormField{
  default: term(),
  flags: %{required(atom()) =&gt; boolean()},
  name: String.t() | nil,
  partial_name: String.t() | nil,
  rect: {number(), number(), number(), number()} | nil,
  tooltip: String.t() | nil,
  type: field_type(),
  value: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
