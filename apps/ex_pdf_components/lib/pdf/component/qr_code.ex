defmodule Pdf.Component.QrCode do
  @moduledoc """
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
  """

  @default_size 100
  @default_color {0, 0, 0}
  @default_background {1, 1, 1}
  @default_quiet_zone 2
  @default_font "Helvetica"

  @doc """
  Render a QR code onto the PDF document.

  `{x, y}` is the top-left corner. The QR code grows downward.
  """
  def render(doc, {x, y}, style \\ %{}) do
    data = Map.get(style, :data, "")
    size = Map.get(style, :size, @default_size)
    ec_level = Map.get(style, :ec_level, :m)
    color = Map.get(style, :color, @default_color)
    bg = Map.get(style, :background, @default_background)
    quiet_zone = Map.get(style, :quiet_zone, @default_quiet_zone)
    padding = Map.get(style, :padding, 0)

    # Border
    border_w = Map.get(style, :border, 0)
    border_color = Map.get(style, :border_color, {0.8, 0.8, 0.8})
    border_radius = Map.get(style, :border_radius, 0)
    border_fill = Map.get(style, :border_fill)

    # Logo
    logo = Map.get(style, :logo)
    logo_size = Map.get(style, :logo_size, round(size * 0.2))
    logo_bg = Map.get(style, :logo_background, bg)
    logo_pad = Map.get(style, :logo_padding, 3)
    logo_radius = Map.get(style, :logo_border_radius, 4)

    # Label
    label = Map.get(style, :label)
    label_font = Map.get(style, :label_font, @default_font)
    label_fs = Map.get(style, :label_font_size, 8)
    label_color = Map.get(style, :label_color, color)
    label_bold = Map.get(style, :label_bold, false)

    # Total outer size includes padding
    outer_size = size + padding * 2

    case ExQR.encode(data, ec_level) do
      {:ok, matrix, qr_size} ->
        total_modules = qr_size + quiet_zone * 2
        module_size = size / total_modules

        # Outer box origin (bottom-left)
        ox = x
        oy = y - outer_size

        # Border fill (card background)
        doc =
          if border_fill do
            doc
            |> Pdf.save_state()
            |> Pdf.set_fill_color(border_fill)
            |> draw_rect({ox, oy}, {outer_size, outer_size}, border_radius)
            |> Pdf.fill()
            |> Pdf.restore_state()
          else
            doc
          end

        # Border stroke
        doc =
          if border_w > 0 do
            doc
            |> Pdf.save_state()
            |> Pdf.set_stroke_color(border_color)
            |> Pdf.set_line_width(border_w)
            |> draw_rect({ox, oy}, {outer_size, outer_size}, border_radius)
            |> Pdf.stroke()
            |> Pdf.restore_state()
          else
            doc
          end

        # QR area origin (inside padding)
        qx = x + padding
        qy = y - padding

        # QR background
        doc =
          doc
          |> Pdf.save_state()
          |> Pdf.set_fill_color(bg)
          |> Pdf.rectangle({qx, qy - size}, {size, size})
          |> Pdf.fill()
          |> Pdf.restore_state()

        # Draw dark modules
        doc = Pdf.save_state(doc) |> Pdf.set_fill_color(color)

        doc =
          Enum.reduce(0..(qr_size - 1), doc, fn row, d ->
            Enum.reduce(0..(qr_size - 1), d, fn col, d ->
              if Map.get(matrix, {row, col}, 0) == 1 do
                mx = qx + (quiet_zone + col) * module_size
                my = qy - (quiet_zone + row + 1) * module_size

                d
                |> Pdf.rectangle({mx, my}, {module_size, module_size})
                |> Pdf.fill()
              else
                d
              end
            end)
          end)

        doc = Pdf.restore_state(doc)

        # Logo overlay in center
        doc =
          if logo do
            draw_logo(doc, logo, {qx, qy}, size, logo_size, logo_bg, logo_pad, logo_radius)
          else
            doc
          end

        # Label below QR
        if label do
          label_y = oy - label_fs - 2
          text_w = String.length(label) * label_fs * 0.55
          label_x = x + (outer_size - text_w) / 2

          font_opts = if label_bold, do: [bold: true], else: []

          doc
          |> Pdf.set_font(label_font, label_fs, font_opts)
          |> Pdf.set_fill_color(label_color)
          |> Pdf.text_at({label_x, label_y}, label)
        else
          doc
        end

      {:error, _reason} ->
        doc
    end
  end

  # ── Drawing helpers ────────────────────────────────────────────

  defp draw_rect(doc, {x, y}, {w, h}, radius) when radius > 0 do
    Pdf.rounded_rectangle(doc, {x, y}, {w, h}, radius)
  end

  defp draw_rect(doc, {x, y}, {w, h}, _radius) do
    Pdf.rectangle(doc, {x, y}, {w, h})
  end

  # ── Logo overlay ───────────────────────────────────────────────

  defp draw_logo(doc, logo, {qx, qy}, size, logo_size, logo_bg, logo_pad, logo_radius) do
    # Center of QR
    cx = qx + size / 2
    cy = qy - size / 2

    # Logo background area (larger, includes padding)
    bg_size = logo_size + logo_pad * 2
    bg_x = cx - bg_size / 2
    bg_y = cy - bg_size / 2

    # Draw white/colored background behind logo
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(logo_bg)
      |> draw_rect({bg_x, bg_y}, {bg_size, bg_size}, logo_radius)
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Draw logo image clipped to rounded rect
    img_x = cx - logo_size / 2
    img_y = cy - logo_size / 2

    if logo_radius > 0 do
      doc
      |> Pdf.save_state()
      |> Pdf.rounded_rectangle({img_x, img_y}, {logo_size, logo_size}, max(logo_radius - logo_pad, 2))
      |> Pdf.clip()
      |> Pdf.add_image({img_x, img_y}, logo, width: logo_size, height: logo_size)
      |> Pdf.restore_state()
    else
      Pdf.add_image(doc, {img_x, img_y}, logo, width: logo_size, height: logo_size)
    end
  end
end
