# `Pdf.Reader.Image`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/image.ex#L1)

Struct representing an image extracted from a PDF page.

Each struct corresponds to one image XObject referenced by a `Do` operator
in the page's content stream.

## Coordinate fields

- `:x`, `:y` — bottom-left translation in user space (CTM e/f components).
- `:width`, `:height` — PIXEL dimensions from the image XObject's `/Width`
  and `/Height` entries (the image's intrinsic resolution). May be `nil` for
  an image XObject without those entries (rare).
- `:render_width`, `:render_height` — user-space rendered dimensions derived
  from the CTM column-vector magnitudes (`sqrt(a*a + b*b)`, `sqrt(c*c + d*d)`).
- `:ctm` — the full 6-float affine matrix `{a, b, c, d, e, f}` at `Do` time.
  Default is the identity matrix `{1.0, 0.0, 0.0, 1.0, 0.0, 0.0}`.
- `:rotation_radians` — `:math.atan2(b, a)` — angle of the x-axis in page space.

For writer-built PDFs using `[pixel_w 0 0 pixel_h x y cm] /Img Do`, pixel and
rendered dimensions agree and `rotation_radians` is `0.0`. For real-world PDFs
that scale or rotate images, the two dimension pairs diverge — use the rendered
dimensions for layout and the pixel dimensions for raster operations.

`:kind` is:
- `:jpeg` — DCTDecode filter; `:bytes` are the raw JPEG-encoded bytes
  (passthrough — suitable for writing directly to a `.jpg` file).
- `:png_like` — FlateDecode+predictor; `:bytes` are decompressed pixel
  data (consumer must supply header information to reconstitute a PNG).

`:ref` is the `{obj_num, gen_num}` pair of the XObject in the PDF. Use
it to de-duplicate images that appear on multiple pages (they share the
same XObject reference).

## Spec references
- PDF 1.7 (ISO 32000-1) § 8.3.3 — Coordinate Systems / Matrix Math:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 8.9.5 — Image Dictionaries (image occupies unit square in user space):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

# `kind`

```elixir
@type kind() :: :jpeg | :png_like
```

# `t`

```elixir
@type t() :: %Pdf.Reader.Image{
  bytes: binary() | nil,
  ctm: {float(), float(), float(), float(), float(), float()},
  height: float() | nil,
  kind: kind() | nil,
  page: pos_integer() | nil,
  ref: {pos_integer(), non_neg_integer()} | nil,
  render_height: float(),
  render_width: float(),
  rotation_radians: float(),
  width: float() | nil,
  x: float(),
  y: float()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
