# `Pdf.StyledTable`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.5/lib/pdf/styled_table.ex#L1)

Styled table component with CSS-like configuration for PDF generation.

## Ejemplo de uso

    data = [
      ["Nombre", "Cantidad", "Precio"],
      ["Producto A", "10", "$100.00"],
      [{:regular, "Producto B"}, {:bold, "5"}, {:regular, "$50.00"}]
    ]

    Pdf.StyledTable.render(doc, data, %{
      columns: [
        %{width: 200, align: :left},
        %{width: 50, align: :center},
        %{width: 100, align: :right}
      ],
      header: %{bold: true, background: "#E6E6E6", padding: 5},
      row: %{padding: 5, border_bottom: 0.5},
      border: 1
    })

Este componente incluye soporte para:
- Ajuste de texto automático (Word-wrap).
- Estilos dinámicos por fila (Header, Body, Alt-row).
- Texto enriquecido (Rich Text) pasando tuplas `{:bold, "texto"}` o `{:regular, "texto"}`.

# `render`

Render a styled table on the document at the current cursor position.

Returns the updated document with cursor moved below the table.

## Options

- `:columns` — list of column config maps: `%{width: n, align: :left|:center|:right, style: %{}}`
- `:header` — style map for header row (first row of data), or `nil` to treat all rows as body
- `:row` — default style map for body rows
- `:alt_row` — style map merged into every other body row (zebra stripes)
- `:footer` — style map for the last row
- `:border` — outer border width (number)
- `:border_color` — outer border color
- `:border_radius` — corner radius for outer border
- `:background` — default cell background
- `:padding` — default cell padding (CSS shorthand)
- `:font`, `:font_size`, `:color` — default text styling
- `:line_height` — height per text line in points

# `render_on_page`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
