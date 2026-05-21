# `Pdf.Component.Footnote`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/footnote.ex#L1)

Footnote component for PDF documents.

Renders footnotes at a given position with a separator line,
superscript numbers, and smaller text.

## Examples

    doc |> Pdf.Component.Footnote.render({50, 100}, %{width: 450}, [
      "Source: World Bank Data, 2025",
      "All figures adjusted for inflation",
      "Excluding outlier regions"
    ])

# `render`

Render footnotes at `{x, y}`.

## Style options

- `:width` — available width (default `450`)
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — text size (default `7`)
- `:color` — text color
- `:line_color` — separator line color
- `:line_height` — spacing between notes (default `11`)
- `:separator_width` — width of the top separator line (default `80`)
- `:start_number` — first footnote number (default `1`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
