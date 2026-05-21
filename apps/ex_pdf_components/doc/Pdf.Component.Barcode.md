# `Pdf.Component.Barcode`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/component/barcode.ex#L1)

Barcode PDF component — renders Code 128 barcodes onto a PDF.

This is a **thin renderer**. All encoding logic (standard and shaped)
lives in `ex_barcode`. This component only scales and draws.

## Standard barcode

    Pdf.Component.Barcode.render(doc, {50, 700}, %{data: "ABC-12345", width: 200})

## Shape barcode (creative barcode with silhouette + decorations)

    Pdf.Component.Barcode.render(doc, {50, 700}, %{
      data: "SPOT2NITE", width: 250, height: 100, shape: :rv
    })

## Style options

### Core
  - `:data` — the string to encode (required)
  - `:width` — barcode width in points (default `200`)
  - `:height` — bar height in points (default `50`, or auto from aspect ratio)
  - `:color` — bar color (default `{0, 0, 0}`)
  - `:background` — optional background color (standard barcodes only)
  - `:quiet_zone` — modules of white space (default `10` standard, `2` shaped)

### Text
  - `:show_text` — render data below bars (default `true`)
  - `:font` / `:font_size` / `:text_color` — text styling
  - `:label` — optional title above barcode
  - `:label_font_size` / `:label_color` — label styling

### Image
  - `:image` — path, URL, or `{:binary, data}`
  - `:image_size` — `{w, h}` (default `{40, 40}`)
  - `:image_position` — `:left`, `:right`, `:top` (default `:left`)
  - `:image_gap` — gap between image and barcode (default `8`)
  - `:image_border_radius` — rounded clip (default `0`)

### Shape (delegated to `ExBarcode.Shape`)
  - `:shape` — predefined shape: `:rv`, `:camper`, `:city`, `:wave`, `:diamond`, `:hill`
  - `:contour_top` — custom top contour `[{x_pct, y_pct}, ...]`
  - `:contour_bottom` — custom bottom contour
  - `:bar_min_height` — minimum bar fraction (default `0.0`)
  - `:decoration_color` — color for decorations (default same as `:color`)
  - `:decoration_stroke_color` — stroke color for stroke decorations (default lighter)

# `render`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
