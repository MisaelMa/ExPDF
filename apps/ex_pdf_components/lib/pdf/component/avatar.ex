defmodule Pdf.Component.Avatar do
  @moduledoc """
  Avatar component for PDF documents.

  Renders a circular (or rounded) container with an image or initials,
  with optional border and elevation (box-shadow simulation).

  Inspired by Material UI's Avatar component.

  ## Examples

      # Avatar with initials
      doc
      |> Pdf.Component.Avatar.render({100, 700}, %{
        size: 48,
        initials: "AM",
        background: {0.3, 0.5, 0.9},
        color: :white,
        elevation: 2
      })

      # Avatar with image
      doc
      |> Pdf.Component.Avatar.render({200, 700}, %{
        size: 64,
        image: "path/to/photo.jpg",
        border: 2,
        border_color: :white,
        elevation: 3
      })
  """

  @default_size 40
  @default_background {0.74, 0.74, 0.74}
  @default_color {1.0, 1.0, 1.0}
  @default_font "Helvetica"

  @doc """
  Render an avatar at `{x, y}` (top-left corner).

  ## Style options

  - `:size` — single number or `{width, height}` tuple in points (default `40`)
  - `:initials` — 1-3 character string to display (default `nil`)
  - `:image` — path to JPEG/PNG image or `{:binary, data}` (default `nil`)
  - `:background` — fill color behind initials (default gray)
  - `:color` — text color for initials (default white)
  - `:font` — font name for initials (default `"Helvetica"`)
  - `:border` — border width (default `0`)
  - `:border_color` — border color (default `:black`)
  - `:border_radius` — `:circle` (default), `:rounded`, or number
  - `:elevation` — shadow level 0-5, like Material UI (default `0`)
  """
  def render(doc, {x, y}, style \\ %{}) do
    {w, h} = normalize_size(Map.get(style, :size, @default_size))
    bg = Map.get(style, :background, @default_background)
    color = Map.get(style, :color, @default_color)
    font = Map.get(style, :font, @default_font)
    initials = Map.get(style, :initials)
    image = Map.get(style, :image)
    border_w = Map.get(style, :border, 0)
    border_color = Map.get(style, :border_color, :black)
    elevation = Map.get(style, :elevation, 0)
    radius = resolve_radius(Map.get(style, :border_radius, :circle), min(w, h))

    # Position: {x, y} is top-left, PDF coords have y going up
    # So the box bottom-left is {x, y - h}
    bx = x
    by = y - h

    doc = draw_shadow(doc, {bx, by}, {w, h}, radius, elevation)
    doc = draw_background(doc, {bx, by}, {w, h}, radius, bg)
    doc = draw_image_or_initials(doc, {bx, by}, {w, h}, radius, image, initials, color, font)
    draw_border(doc, {bx, by}, {w, h}, radius, border_w, border_color)
  end

  # ── Shadow / Elevation ──────────────────────────────────────────

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

  # Shadow layers: {offset_x, offset_y, spread, opacity}
  # offset_y positive = shadow moves DOWN (subtract from PDF y)
  # Small spreads + low opacity = subtle, realistic shadows

  defp shadow_layers(1) do
    [
      {0, -0.5, 1.0, 0.06},
      {0, -0.3, 0.5, 0.04}
    ]
  end

  defp shadow_layers(2) do
    [
      {0, -1.0, 1.5, 0.07},
      {0, -0.5, 1.0, 0.05},
      {0, -0.2, 0.5, 0.03}
    ]
  end

  defp shadow_layers(3) do
    [
      {0, -1.5, 2.0, 0.08},
      {0, -0.8, 1.5, 0.05},
      {0, -0.3, 0.8, 0.03}
    ]
  end

  defp shadow_layers(4) do
    [
      {0, -2.0, 2.5, 0.09},
      {0, -1.2, 2.0, 0.06},
      {0, -0.5, 1.0, 0.04},
      {0, -0.2, 0.5, 0.02}
    ]
  end

  defp shadow_layers(n) when n >= 5 do
    [
      {0, -3.0, 3.5, 0.10},
      {0, -2.0, 2.5, 0.07},
      {0, -1.0, 1.5, 0.05},
      {0, -0.5, 1.0, 0.03},
      {0, -0.2, 0.5, 0.02}
    ]
  end

  # ── Background ──────────────────────────────────────────────────

  defp draw_background(doc, {x, y}, {w, h}, radius, bg) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({x, y}, {w, h}, radius)
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  # ── Image or Initials ───────────────────────────────────────────

  defp draw_image_or_initials(doc, {x, y}, {w, h}, radius, image, _initials, _color, _font)
       when not is_nil(image) do
    doc
    |> Pdf.save_state()
    |> Pdf.rounded_rectangle({x, y}, {w, h}, radius)
    |> Pdf.clip()
    |> Pdf.add_image({x, y}, image, width: w, height: h)
    |> Pdf.restore_state()
  end

  defp draw_image_or_initials(doc, {x, y}, {w, h}, _radius, _image, initials, color, font)
       when is_binary(initials) and byte_size(initials) > 0 do
    font_size = font_size_for_initials(initials, min(w, h))
    text_w = String.length(initials) * font_size * 0.6
    text_h = font_size * 0.7

    tx = x + (w - text_w) / 2
    ty = y + (h - text_h) / 2

    doc
    |> Pdf.save_state()
    |> Pdf.set_font(font, font_size)
    |> Pdf.set_fill_color(color)
    |> Pdf.text_at({tx, ty}, initials)
    |> Pdf.restore_state()
  end

  defp draw_image_or_initials(doc, _pos, _size, _radius, _image, _initials, _color, _font) do
    doc
  end

  # ── Border ──────────────────────────────────────────────────────

  defp draw_border(doc, _pos, _size, _radius, 0, _color), do: doc

  defp draw_border(doc, {x, y}, {w, h}, radius, border_w, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(border_w)
    |> Pdf.rounded_rectangle({x, y}, {w, h}, radius)
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp normalize_size({w, h}), do: {w, h}
  defp normalize_size(s) when is_number(s), do: {s, s}

  defp resolve_radius(:circle, min_dim), do: min_dim / 2
  defp resolve_radius(:rounded, min_dim), do: min_dim * 0.2
  defp resolve_radius(r, _min_dim) when is_number(r), do: r

  defp font_size_for_initials(text, size) do
    len = String.length(text)

    cond do
      len <= 1 -> size * 0.5
      len == 2 -> size * 0.38
      true -> size * 0.3
    end
  end

  defp set_fill_opacity(doc, opacity) when opacity < 1.0 do
    Pdf.set_fill_opacity(doc, opacity)
  end

  defp set_fill_opacity(doc, _opacity), do: doc
end
