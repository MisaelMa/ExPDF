# `Pdf.Component.List`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/list.ex#L1)

List component for PDF documents.

Renders bulleted or numbered lists with support for nesting,
custom markers, and per-level styling.

## Examples

    doc |> Pdf.Component.List.render({50, 700}, %{}, [
      "First item",
      "Second item",
      {:nested, ["Sub-item A", "Sub-item B"]},
      "Third item"
    ])

    doc |> Pdf.Component.List.render({50, 700}, %{type: :numbered}, [
      "Step one",
      "Step two",
      "Step three"
    ])

# `render`

Render a list at `{x, y}`.

## Style options

- `:type` — `:bullet` (default) or `:numbered`
- `:font` — font name (default `"Helvetica"`)
- `:font_size` — text size (default `10`)
- `:color` — text color (default dark)
- `:line_height` — spacing between items (default `16`)
- `:indent` — indentation per nesting level (default `15`)
- `:marker_gap` — space between marker and text (default `8`)
- `:marker_color` — marker color (defaults to `:color`)

## Items format

Items is a flat list where:
- `"string"` — a list item
- `{:nested, [items]}` — a nested sub-list

---

*Consult [api-reference.md](api-reference.md) for complete listing*
