# `Pdf.Component.Progress`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/progress.ex#L1)

Progress bar component for PDF documents.

Renders a horizontal progress/percentage bar with track and fill,
optional label, and rounded or square ends.

Inspired by Material UI's LinearProgress component.

## Examples

    # Simple progress bar
    doc |> Pdf.Component.Progress.render({50, 400}, %{width: 200, value: 75})

    # Styled progress bar with label
    doc |> Pdf.Component.Progress.render({50, 400}, %{
      width: 300,
      value: 42,
      color: {0.18, 0.72, 0.45},
      show_label: true,
      height: 16,
      border_radius: :rounded
    })

# `render`

Render a progress bar at `{x, y}` (top-left corner).

## Style options

- `:width` — total bar width (default `200`)
- `:height` — bar height (default `8`)
- `:value` — progress percentage 0-100 (default `0`)
- `:color` — fill color (default blue)
- `:track_color` — background track color (default light gray)
- `:border_radius` — `:rounded` (default), `:square`, or number
- `:show_label` — show percentage text (default `false`)
- `:label_color` — text color for label (default dark gray)
- `:font` — font name (default `"Helvetica"`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
