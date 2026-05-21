# `Pdf.Component.Chip`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/chip.ex#L1)

Chip component for PDF documents.

Renders a compact rounded label/tag element, useful for displaying
categories, tags, status indicators, or filter selections.

Inspired by Material UI's Chip component.

## Examples

    # Simple chip
    doc |> Pdf.Component.Chip.render({50, 400}, %{label: "Elixir"})

    # Outlined chip
    doc |> Pdf.Component.Chip.render({50, 400}, %{
      label: "Active",
      variant: :outlined,
      color: {0.18, 0.72, 0.45}
    })

    # Filled chip with custom colors
    doc |> Pdf.Component.Chip.render({50, 400}, %{
      label: "Priority",
      background: {0.85, 0.26, 0.33},
      color: :white
    })

# `render`

Render a chip at `{x, y}` (top-left corner).

Returns `{doc, width}` — the document and the rendered chip width.

## Style options

- `:label` — text to display (required)
- `:variant` — `:filled` (default) or `:outlined`
- `:background` — fill color for filled variant (default light gray)
- `:color` — text/border color (default dark gray)
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — font size (default `10`)
- `:height` — chip height in points (default `24`)
- `:padding_h` — horizontal padding (default `10`)
- `:border` — border width for outlined variant (default `1`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
