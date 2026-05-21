# `ExBarcode.Shape`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_barcode/shape.ex#L1)

Shape barcode engine — transforms a standard Code 128 barcode into a
shaped barcode with two rendering styles:

## Styles

### `:silhouette` (animals, objects)
Solid filled silhouette (head, ears, tail, legs) with barcode bars placed
inside a rectangular region within the body. Like a cookie-cutter: the
animal is solid, the barcode is the "window" inside it.

### `:contour` (geometric, abstract)
Bars with variable heights following a top/bottom contour, with optional
decorations (circles, polygons, lines).

## Output

All coordinates are **normalized** to a 0.0–1.0 bounding box so
any renderer (PDF, SVG, Canvas) can scale to the desired size.

    %ExBarcode.Shape.Result{
      style: :silhouette,
      bars: [%{x: 0.20, y: 0.10, w: 0.005, h: 0.50}, ...],
      silhouette: [[{0.05, 0.40}, {0.10, 0.55}, ...]],
      barcode_region: {0.20, 0.08, 0.60, 0.52},
      cutouts: [{:circle_bg, {0.12, 0.52, 0.02}}],
      decorations: [{:circle, {0.11, 0.52, 0.006}}],
      text: "BUNNY",
      aspect_ratio: 1.8
    }

# `available_shapes`

List all available predefined shapes.

# `encode`

Encode text as a shaped barcode.

## Options

  - `:shape` — predefined shape atom (see `available_shapes/0`)
  - `:contour_top` — custom top contour `[{x_pct, y_pct}, ...]`
  - `:contour_bottom` — custom bottom contour
  - `:quiet_zone` — modules of padding per side (default `2`)
  - `:bar_min` — minimum bar height fraction (default `0.0`)

# `encode!`

Same as `encode/2` but raises on error.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
