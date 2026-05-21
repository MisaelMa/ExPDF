# `Pdf.Component.Divider`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/divider.ex#L1)

Divider component for PDF documents.

Renders a horizontal or vertical line separator with configurable
color, width, style (solid/dashed), and margin.

Inspired by Material UI's Divider component.

## Examples

    # Simple horizontal divider
    doc |> Pdf.Component.Divider.render({50, 400}, %{width: 200})

    # Dashed divider with color
    doc |> Pdf.Component.Divider.render({50, 400}, %{
      width: 200,
      color: {0.8, 0.8, 0.8},
      style: :dashed,
      thickness: 0.5
    })

    # Vertical divider
    doc |> Pdf.Component.Divider.render({250, 700}, %{
      height: 100,
      orientation: :vertical
    })

# `render`

Render a divider at `{x, y}`.

## Style options

- `:width` — length for horizontal dividers (default `0`, required for horizontal)
- `:height` — length for vertical dividers (default `0`, required for vertical)
- `:orientation` — `:horizontal` (default) or `:vertical`
- `:color` — line color (default light gray)
- `:thickness` — line width in points (default `0.5`)
- `:style` — `:solid` (default) or `:dashed`
- `:dash` — custom dash pattern `{on, off}` (default `{3, 3}`)
- `:margin_top` — space above (default `0`)
- `:margin_bottom` — space below (default `0`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
