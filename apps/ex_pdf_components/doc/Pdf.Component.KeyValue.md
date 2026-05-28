# `Pdf.Component.KeyValue`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/key_value.ex#L1)

Key-value pair component for PDF documents.

Renders aligned label-value rows, like invoice details or profile info.

## Examples

    doc |> Pdf.Component.KeyValue.render({50, 700}, %{width: 300}, [
      {"Name:", "John Doe"},
      {"Email:", "john@example.com"},
      {"Role:", "Admin"}
    ])

# `measure_height`

Calculate the total height this key-value list will occupy,
accounting for word-wrap on long values.

Takes the same `style` map as `render/4` plus the `pairs` list.
Returns the height in points.

# `render`

Render key-value pairs at `{x, y}`.

## Style options

- `:width` — total width (default `300`)
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — text size (default `10`)
- `:label_color` — label text color
- `:value_color` — value text color
- `:line_height` — row spacing (default `18`)
- `:label_width` — fraction of width for labels (default `0.35`)
- `:divider` — show divider between rows (default `false`)
- `:divider_color` — divider line color
- `:striped` — alternate row backgrounds (default `false`)
- `:stripe_color` — background for even rows
- `:value_align` — `:left` (default) or `:right` to right-align values
- `:label_bold` — bold labels (default `true`)
- `:value_bold` — bold values (default `false`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
