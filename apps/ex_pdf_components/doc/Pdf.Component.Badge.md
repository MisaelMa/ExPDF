# `Pdf.Component.Badge`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/badge.ex#L1)

Badge component for PDF documents.

Renders a small circle or pill-shaped label, typically used to show
counts, notifications, or status indicators overlaid on another element.

Inspired by Material UI's Badge component.

## Examples

    # Simple notification badge
    doc |> Pdf.Component.Badge.render({120, 710}, %{content: "3"})

    # Custom styled badge
    doc |> Pdf.Component.Badge.render({200, 700}, %{
      content: "NEW",
      background: {0.18, 0.72, 0.45},
      color: :white,
      variant: :pill
    })

# `render`

Render a badge at `{x, y}` (center point).

## Style options

- `:content` — text to display (default `""`)
- `:background` — fill color (default red)
- `:color` — text color (default white)
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — font size (default `8`)
- `:size` — diameter for dot/circle variant (default `18`)
- `:variant` — `:dot` (no text), `:standard` (circle), or `:pill` (auto-width)
- `:border` — border width (default `0`)
- `:border_color` — border color (default `:white`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
