defmodule Pdf.Component.Card do
  @moduledoc """
  Card component for PDF documents.

  Renders a container with optional header, body, and footer sections,
  elevation (box-shadow), and rounded corners. Designed for structured
  content blocks like profile cards, info panels, and summaries.

  Inspired by Material UI's Card component.

  ## Examples

      # Simple card with callback
      doc |> Pdf.Component.Card.render({50, 700}, {300, 150}, %{
        elevation: 2,
        border_radius: 8
      }, fn doc, area ->
        doc |> Pdf.text_at({area.x, area.y - 14}, "Card content")
      end)

      # Card with header and body
      doc |> Pdf.Component.Card.render({50, 700}, {300, 200}, %{
        elevation: 3,
        header: %{title: "User Profile", subtitle: "Senior Developer"},
        padding: 12
      }, fn doc, area ->
        doc |> Pdf.text_at({area.x, area.y - 14}, "Card body content here")
      end)
  """

  @default_background {1.0, 1.0, 1.0}
  @default_border_radius 8
  @default_padding 12
  @default_header_bg {0.97, 0.97, 0.97}
  @default_header_border {0.90, 0.90, 0.90}

  @doc """
  Render a card at `{x, y}` (top-left) with size `{w, h}`.

  ## Style options

  - `:background` — card background color (default white)
  - `:border_radius` — corner radius (default `8`)
  - `:border` — border width (default `0`)
  - `:border_color` — border color (default light gray)
  - `:elevation` — shadow level 0-5 (default `1`)
  - `:padding` — inner padding (default `12`)
  - `:header` — map with `:title`, `:subtitle`, `:background`, `:height`
  - `:footer` — map with `:text`, `:background`, `:height`

  The callback receives `fn doc, area -> ... end` where `area` is the
  content area after header and padding are accounted for.
  """
  def render(doc, {x, y}, {w, h}, style \\ %{}, callback \\ nil) do
    bg = Map.get(style, :background, @default_background)
    radius = Map.get(style, :border_radius, @default_border_radius)
    border_w = Map.get(style, :border, 0)
    border_color = Map.get(style, :border_color, {0.88, 0.88, 0.88})
    elevation = Map.get(style, :elevation, 1)
    padding = Map.get(style, :padding, @default_padding)
    header = Map.get(style, :header)
    footer = Map.get(style, :footer)

    # PDF coords: {x, y} is top-left, so bottom-left = {x, y - h}
    bx = x
    by = y - h

    # Shadow
    doc = draw_shadow(doc, {bx, by}, {w, h}, radius, elevation)

    # Background
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({bx, by}, {w, h}, radius)
    |> Pdf.fill()
    |> Pdf.restore_state()

    # Header
    {doc, header_h} = draw_header(doc, {bx, y}, w, radius, header)

    # Footer
    {doc, footer_h} = draw_footer(doc, {bx, by}, w, radius, footer)

    # Border (on top of everything)
    doc = if border_w > 0 do
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(border_color)
      |> Pdf.set_line_width(border_w)
      |> Pdf.rounded_rectangle({bx, by}, {w, h}, radius)
      |> Pdf.stroke()
      |> Pdf.restore_state()
    else
      doc
    end

    # Content area callback
    if is_function(callback, 2) do
      content_area = %{
        x: bx + padding,
        y: y - header_h - padding,
        width: w - padding * 2,
        height: h - header_h - footer_h - padding * 2
      }
      callback.(doc, content_area)
    else
      doc
    end
  end

  # ── Header ─────────────────────────────────────────────────────

  defp draw_header(doc, _pos, _w, _radius, nil), do: {doc, 0}

  defp draw_header(doc, {x, y}, w, radius, header) when is_map(header) do
    height = Map.get(header, :height, 40)
    bg = Map.get(header, :background, @default_header_bg)
    title = Map.get(header, :title, "")
    subtitle = Map.get(header, :subtitle)
    title_color = Map.get(header, :title_color, {0.1, 0.1, 0.1})
    subtitle_color = Map.get(header, :subtitle_color, {0.5, 0.5, 0.5})

    by = y - height

    # Clip header to card's top rounded corners
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({x, by}, {w, height}, radius)
    |> Pdf.fill()

    # Header bottom border
    doc = doc
    |> Pdf.set_stroke_color(@default_header_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({x, by}, {x + w, by})
    |> Pdf.stroke()

    # Title
    doc = if title != "" do
      title_y = if subtitle, do: y - 16, else: y - height / 2 - 5
      doc
      |> Pdf.set_font("Helvetica", 12, bold: true)
      |> Pdf.set_fill_color(title_color)
      |> Pdf.text_at({x + 12, title_y}, title)
    else
      doc
    end

    # Subtitle
    doc = if subtitle do
      doc
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(subtitle_color)
      |> Pdf.text_at({x + 12, y - 30}, subtitle)
    else
      doc
    end

    doc = Pdf.restore_state(doc)
    {doc, height}
  end

  # ── Footer ─────────────────────────────────────────────────────

  defp draw_footer(doc, _pos, _w, _radius, nil), do: {doc, 0}

  defp draw_footer(doc, {x, by}, w, radius, footer) when is_map(footer) do
    height = Map.get(footer, :height, 32)
    bg = Map.get(footer, :background, @default_header_bg)
    text = Map.get(footer, :text, "")
    text_color = Map.get(footer, :text_color, {0.5, 0.5, 0.5})

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({x, by}, {w, height}, radius)
    |> Pdf.fill()

    # Footer top border
    fy = by + height
    doc = doc
    |> Pdf.set_stroke_color(@default_header_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({x, fy}, {x + w, fy})
    |> Pdf.stroke()

    # Footer text
    doc = if text != "" do
      doc
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(text_color)
      |> Pdf.text_at({x + 12, by + height / 2 - 4}, text)
    else
      doc
    end

    doc = Pdf.restore_state(doc)
    {doc, height}
  end

  # ── Shadow (reuse Avatar pattern) ──────────────────────────────

  defp draw_shadow(doc, _pos, _size, _radius, 0), do: doc

  defp draw_shadow(doc, {x, y}, {w, h}, radius, elevation) when elevation > 0 do
    layers = shadow_layers(elevation)

    Enum.reduce(layers, doc, fn {offset_x, offset_y, spread, opacity}, doc ->
      sx = x + offset_x - spread
      sy = y + offset_y - spread
      sw = w + spread * 2
      sh = h + spread * 2
      sr = min(radius + spread, min(sw, sh) / 2)

      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color({0.0, 0.0, 0.0})
      |> set_fill_opacity(opacity)
      |> Pdf.rounded_rectangle({sx, sy}, {sw, sh}, sr)
      |> Pdf.fill()
      |> Pdf.restore_state()
    end)
  end

  defp set_fill_opacity(doc, opacity) do
    Pdf.set_fill_opacity(doc, opacity)
  end

  defp shadow_layers(1), do: [{0, -0.5, 1.0, 0.06}, {0, -0.3, 0.5, 0.04}]
  defp shadow_layers(2), do: [{0, -1.0, 1.5, 0.07}, {0, -0.5, 1.0, 0.05}, {0, -0.2, 0.5, 0.03}]
  defp shadow_layers(3), do: [{0, -1.5, 2.0, 0.08}, {0, -0.8, 1.5, 0.05}, {0, -0.3, 0.8, 0.03}]
  defp shadow_layers(4), do: [{0, -2.0, 2.5, 0.09}, {0, -1.2, 2.0, 0.06}, {0, -0.5, 1.0, 0.04}, {0, -0.2, 0.5, 0.02}]
  defp shadow_layers(n) when n >= 5, do: [{0, -3.0, 3.5, 0.10}, {0, -2.0, 2.5, 0.07}, {0, -1.0, 1.5, 0.05}, {0, -0.5, 1.0, 0.03}, {0, -0.2, 0.5, 0.02}]
end
