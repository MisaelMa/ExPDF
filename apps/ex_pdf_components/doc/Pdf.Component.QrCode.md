# `Pdf.Component.QrCode`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/component/qr_code.ex#L1)

QR Code PDF component — renders a QR code at a given position.

## Usage via Builder

    %{type: :qr, props: %{
      data: "https://example.com",
      style: %{
        position: {50, 700},
        size: 120,
        ec_level: :h,
        logo: "https://example.com/icon.png",
        logo_size: 30,
        label: "Scan me"
      }
    }}

## Style options

### Core
  - `:data` — the string to encode (required)
  - `:size` — QR code size in points, square (default `100`)
  - `:ec_level` — error correction: `:l`, `:m` (default), `:q`, `:h`
  - `:color` — module (dark) color (default `{0, 0, 0}`)
  - `:background` — light module color (default `{1, 1, 1}`)
  - `:quiet_zone` — number of quiet zone modules (default `2`)

### Border & padding
  - `:border` — border width (default `0`)
  - `:border_color` — border stroke color (default `{0.8, 0.8, 0.8}`)
  - `:border_radius` — corner radius (default `0`)
  - `:border_fill` — fill color for border area / card background (default `nil`)
  - `:padding` — extra padding between border and QR (default `0`)

### Logo / icon overlay (center of QR)
  - `:logo` — image path, URL, or `{:binary, data}` (default `nil`)
  - `:logo_size` — logo width & height in points (default 20% of `:size`)
  - `:logo_background` — background behind logo (default `:background`)
  - `:logo_padding` — padding around logo image (default `3`)
  - `:logo_border_radius` — rounded clip for logo area (default `4`)

### Label
  - `:label` — text rendered below the QR code (default `nil`)
  - `:label_font` — font name (default `"Helvetica"`)
  - `:label_font_size` — font size (default `8`)
  - `:label_color` — text color (default same as `:color`)
  - `:label_bold` — bold label (default `false`)

# `render`

Render a QR code onto the PDF document.

`{x, y}` is the top-left corner. The QR code grows downward.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
