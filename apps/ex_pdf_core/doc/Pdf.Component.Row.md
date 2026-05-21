# `Pdf.Component.Row`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/component/row.ex#L1)

Row component for PDF documents.

Distributes content horizontally in columns by weight.
Operates at Document level.

## Example

    doc
    |> Pdf.Component.Row.render({50, 700}, {400, 80}, [
      {1, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Col 1") end},
      {2, fn doc, area -> Pdf.text_at(doc, {area.x, area.y - 14}, "Col 2") end}
    ], gap: 10)

# `render`

Render a horizontal row at `{x, y}` with size `{w, h}`.

`columns` is a list of `{weight, callback}` tuples where each callback
receives `(doc, %{x, y, width, height})`.

## Options

- `:gap` — space between columns (default `0`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
