# `Pdf.Reader.Result.Page`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/result.ex#L51)

Per-page slice of the unified extraction result.

`:lines` contains both text lines (with `:kind`-tagged tokens
including `:link`, `:email`, `:image`) and synthetic image-only
lines, sorted top-to-bottom on the page.

Spec reference: PDF 1.7 § 7.7.3 — Page Tree.

# `t`

```elixir
@type t() :: %Pdf.Reader.Result.Page{
  lines: [Pdf.Reader.Line.t()],
  meta: map(),
  number: pos_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
