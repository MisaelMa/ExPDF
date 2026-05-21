# `Pdf.Layout`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/layout.ex#L1)

Layout helpers for positioning content in PDF documents.

Provides `box/4`, `row/4`, and `column/4` containers that manage
coordinates, padding, margin, and borders based on `Pdf.Style`.

# `box`

Render content inside a box with padding, margin, border, and optional background.

The callback receives `(page, %{x, y, width, height})` with the inner content area
(after padding/margin are applied) and must return the updated page.

## Example

    Layout.box(page, {50, 700}, {200, 100}, style: %{padding: 10, border: 1}, fn page, area ->
      Page.text_at(page, {area.x, area.y - 12}, "Inside box")
    end)

# `column`

Stack content vertically.

Takes a list of `{height, callback}` tuples. Each item is placed
below the previous one.

## Example

    Layout.column(page, {50, 700}, {400, 300}, [
      {20, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Row 1") end},
      {20, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Row 2") end}
    ])

# `row`

Distribute content horizontally in columns.

Takes a list of `{weight, callback}` tuples. The available width is
split proportionally by weight.

## Example

    Layout.row(page, {50, 700}, {400, 100}, [
      {1, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Left") end},
      {2, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Center (2x wide)") end},
      {1, fn page, area -> Page.text_at(page, {area.x, area.y - 12}, "Right") end}
    ])

---

*Consult [api-reference.md](api-reference.md) for complete listing*
