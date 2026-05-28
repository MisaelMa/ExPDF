# `Pdf.Component.Avatar`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/avatar.ex#L1)

Avatar component for PDF documents.

Renders a circular (or rounded) container with an image or initials,
with optional border and elevation (box-shadow simulation).

Inspired by Material UI's Avatar component.

## Examples

    # Avatar with initials
    doc
    |> Pdf.Component.Avatar.render({100, 700}, %{
      size: 48,
      initials: "AM",
      background: {0.3, 0.5, 0.9},
      color: :white,
      elevation: 2
    })

    # Avatar with image
    doc
    |> Pdf.Component.Avatar.render({200, 700}, %{
      size: 64,
      image: "path/to/photo.jpg",
      border: 2,
      border_color: :white,
      elevation: 3
    })

# `render`

Render an avatar at `{x, y}` (top-left corner).

## Style options

- `:size` — single number or `{width, height}` tuple in points (default `40`)
- `:initials` — 1-3 character string to display (default `nil`)
- `:image` — path to JPEG/PNG image or `{:binary, data}` (default `nil`)
- `:background` — fill color behind initials (default gray)
- `:color` — text color for initials (default white)
- `:font` — font name for initials (default `"Helvetica"`)
- `:border` — border width (default `0`)
- `:border_color` — border color (default `:black`)
- `:border_radius` — `:circle` (default), `:rounded`, or number
- `:elevation` — shadow level 0-5, like Material UI (default `0`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
