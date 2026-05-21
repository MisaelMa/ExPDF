# `Pdf.Component.Paginator`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/paginator.ex#L1)

Paginator component for PDF documents.

Registers a footer template that renders page numbers on every page.
Uses `Pdf.on_page(:footer, ...)` internally.

## Examples

    doc |> Pdf.Component.Paginator.apply()

    doc |> Pdf.Component.Paginator.apply(%{
      format: :center,
      font_size: 9,
      color: {0.5, 0.5, 0.5},
      prefix: "Page "
    })

# `apply`

Apply page numbering to the document.

This registers a footer template — all subsequent pages will
have page numbers rendered automatically.

## Style options

- `:format` — `:center` (default), `:right`, or `:left`
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — text size (default `9`)
- `:color` — text color (default gray)
- `:margin_bottom` — distance from page bottom (default `30`)
- `:prefix` — text before number (default `"Page "`)
- `:show_total` — show "of N" suffix (default `false`)
- `:total_pages` — total page count (required if `:show_total` is `true`)
- `:separator` — separator between number and total (default `" of "`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
