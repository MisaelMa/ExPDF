# `Pdf.Component.Card`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/card.ex#L1)

Card component for PDF documents.

Renders a container with optional header, body, and footer sections,
elevation (box-shadow), and rounded corners. Designed for structured
content blocks like profile cards, info panels, and summaries.

Inspired by Material UI's Card component.

## Examples

    # Simple card with callback
    doc |> Pdf.Component.Card.render({50, 700}, {300, 150}, %{
      elevation: 2,
      border_radius: 8
    }, fn doc, area ->
      doc |> Pdf.text_at({area.x, area.y - 14}, "Card content")
    end)

    # Card with header and body
    doc |> Pdf.Component.Card.render({50, 700}, {300, 200}, %{
      elevation: 3,
      header: %{title: "User Profile", subtitle: "Senior Developer"},
      padding: 12
    }, fn doc, area ->
      doc |> Pdf.text_at({area.x, area.y - 14}, "Card body content here")
    end)

# `render`

Render a card at `{x, y}` (top-left) with size `{w, h}`.

## Style options

- `:background` — card background color (default white)
- `:border_radius` — corner radius (default `8`)
- `:border` — border width (default `0`)
- `:border_color` — border color (default light gray)
- `:elevation` — shadow level 0-5 (default `1`)
- `:padding` — inner padding (default `12`)
- `:header` — map with `:title`, `:subtitle`, `:background`, `:height`
- `:footer` — map with `:text`, `:background`, `:height`

The callback receives `fn doc, area -> ... end` where `area` is the
content area after header and padding are accounted for.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
