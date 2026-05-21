# `Pdf.Component.Box`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/box.ex#L1)

Box component for PDF documents.

Renders a rectangular container with optional padding, margin, border,
border_radius, and background. Operates at Document level.

## Example

    doc
    |> Pdf.Component.Box.render({50, 700}, {300, 200}, %{
      padding: 10, border: 1, border_radius: 8, background: {0.95, 0.95, 1.0}
    }, fn doc, area ->
      Pdf.text_at(doc, {area.x + 5, area.y - 14}, "Inside the box")
    end)

# `render`

Render a box at `{x, y}` with size `{w, h}`, applying `style` options,
then invoke `callback.(doc, inner_area)`.

## Style options

- `:padding` — inner spacing (CSS shorthand: number, `{v, h}`, `{t, r, b, l}`)
- `:margin` — outer spacing (CSS shorthand)
- `:border` — border width (CSS shorthand)
- `:border_color` — border color (default `:black`)
- `:border_radius` — corner radius (default `0`)
- `:background` — fill color (default `nil`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
