# `Pdf.StyledTable`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/styled_table.ex#L1)

Styled table component with CSS-like configuration.

Renders data tables with customizable borders, rounded corners, backgrounds,
padding, and per-row/cell styling using `Pdf.Style` maps.

## Example

    Pdf.StyledTable.render(doc, [
      ["Name", "Qty", "Price"],
      ["Widget A", "5", "$10.00"],
      ["Widget B", "3", "$15.00"]
    ], %{
      columns: [
        %{width: 200},
        %{width: 80, align: :center},
        %{width: 120, align: :right}
      ],
      header: %{bold: true, background: {0.2, 0.3, 0.5}, color: :white, padding: 8},
      row: %{padding: 6, border_bottom: 1},
      alt_row: %{background: {0.95, 0.95, 1.0}},
      border: 1,
      border_color: {0.3, 0.3, 0.3},
      border_radius: 6
    })

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

Render a styled table on a Page struct (low-level).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
