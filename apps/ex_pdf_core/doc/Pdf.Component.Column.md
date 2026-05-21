# `Pdf.Component.Column`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/column.ex#L1)

Column component for PDF documents.

Stacks content vertically with fixed heights per row.
Operates at Document level.

## Example

    doc
    |> Pdf.Component.Column.render({50, 700}, {300, 400}, [
      {50, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Row 1") end},
      {80, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Row 2") end}
    ], gap: 5)

# `render`

Render a vertical column at `{x, y}` with size `{w, h}`.

`rows` is a list of `{height, callback}` tuples where each callback
receives `(doc, %{x, y, width, height})`.

## Options

- `:gap` — space between rows (default `0`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
