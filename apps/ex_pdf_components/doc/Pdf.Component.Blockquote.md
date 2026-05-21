# `Pdf.Component.Blockquote`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/blockquote.ex#L1)

Blockquote component for PDF documents.

Renders an indented text block with a colored left bar,
optional background, and citation line.

## Examples

    doc |> Pdf.Component.Blockquote.render({50, 700}, %{width: 400},
      "The best way to predict the future is to invent it.")

    doc |> Pdf.Component.Blockquote.render({50, 700}, %{
      width: 400,
      bar_color: {0.2, 0.5, 0.8},
      cite: "— Alan Kay"
    }, "The best way to predict the future is to invent it.")

# `render`

Render a blockquote at `{x, y}`.

## Style options

- `:width` — total width of the blockquote (required)
- `:bar_color` — left accent bar color (default gray)
- `:bar_width` — bar thickness (default `3`)
- `:background` — optional background color
- `:padding` — inner padding (default `12`)
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — text size (default `10`)
- `:color` — text color (default dark gray)
- `:italic` — render text in italic (default `true`)
- `:cite` — optional citation line below the quote
- `:cite_color` — citation text color (default lighter gray)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
