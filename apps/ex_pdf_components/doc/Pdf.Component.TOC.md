# `Pdf.Component.TOC`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/toc.ex#L1)

Table of Contents component for PDF documents.

Renders a list of entries with titles, optional dot leaders,
and right-aligned page numbers.

## Examples

    doc |> Pdf.Component.TOC.render({50, 700}, %{width: 450}, [
      %{title: "Introduction", page: 1},
      %{title: "Getting Started", page: 3, level: 1},
      %{title: "Installation", page: 3, level: 2},
      %{title: "Configuration", page: 5, level: 2},
      %{title: "Advanced Usage", page: 10, level: 1}
    ])

# `render`

Render a table of contents at `{x, y}`.

## Style options

- `:width` — total width (default `450`)
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — base text size (default `10`)
- `:color` — title text color
- `:page_color` — page number color
- `:dot_color` — dot leader color
- `:line_height` — row spacing (default `18`)
- `:indent` — indentation per level (default `20`)
- `:dots` — show dot leaders (default `true`)

## Entries format

List of maps: `%{title: "Section", page: 1, level: 1}`
Level defaults to `1`. Level `0` renders bold (chapter heading).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
