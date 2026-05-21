# `Pdf.Component.Timeline`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/timeline.ex#L1)

Timeline component for PDF documents.

Renders a vertical timeline with dots, connecting line, and event entries.
Useful for CVs, project history, and changelogs.

## Examples

    doc |> Pdf.Component.Timeline.render({50, 700}, %{}, [
      %{date: "2026", title: "Launch", description: "Product released"},
      %{date: "2025", title: "Beta", description: "Beta testing phase"},
      %{date: "2024", title: "Founded", description: "Company started"}
    ])

# `render`

Render a timeline at `{x, y}`.

## Style options

- `:font` — font name (default `"Helvetica"`)
- `:font_size` — text size (default `10`)
- `:color` — title/description color
- `:date_color` — date text color
- `:line_color` — vertical line color
- `:dot_color` — dot fill color
- `:dot_size` — dot diameter (default `6`)
- `:row_height` — height per entry (default `50`)
- `:date_width` — width reserved for dates (default `60`)

## Events format

List of maps: `%{date: "2026", title: "Event", description: "Details"}`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
