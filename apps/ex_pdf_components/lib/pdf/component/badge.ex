defmodule Pdf.Component.Badge do
  @moduledoc """
  Badge component for PDF documents.

  Renders a small circle or pill-shaped label, typically used to show
  counts, notifications, or status indicators overlaid on another element.

  Inspired by Material UI's Badge component.

  ## Examples

      # Simple notification badge
      doc |> Pdf.Component.Badge.render({120, 710}, %{content: "3"})

      # Custom styled badge
      doc |> Pdf.Component.Badge.render({200, 700}, %{
        content: "NEW",
        background: {0.18, 0.72, 0.45},
        color: :white,
        variant: :pill
      })
  """

  @default_background {0.85, 0.26, 0.33}
  @default_color {1.0, 1.0, 1.0}
  @default_font "Helvetica"
  @default_font_size 8
  @default_size 18

  @doc """
  Render a badge at `{x, y}` (center point).

  ## Style options

  - `:content` — text to display (default `""`)
  - `:background` — fill color (default red)
  - `:color` — text color (default white)
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — font size (default `8`)
  - `:size` — diameter for dot/circle variant (default `18`)
  - `:variant` — `:dot` (no text), `:standard` (circle), or `:pill` (auto-width)
  - `:border` — border width (default `0`)
  - `:border_color` — border color (default `:white`)
  """
  def render(doc, {x, y}, style \\ %{}) do
    content = Map.get(style, :content, "")
    bg = Map.get(style, :background, @default_background)
    color = Map.get(style, :color, @default_color)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    size = Map.get(style, :size, @default_size)
    variant = Map.get(style, :variant, :standard)
    border_w = Map.get(style, :border, 0)
    border_color = Map.get(style, :border_color, :white)

    case variant do
      :dot -> draw_dot(doc, {x, y}, size / 2, bg, border_w, border_color)
      :pill -> draw_pill(doc, {x, y}, content, bg, color, font, font_size, size, border_w, border_color)
      _standard -> draw_circle(doc, {x, y}, content, bg, color, font, font_size, size, border_w, border_color)
    end
  end

  defp draw_dot(doc, {cx, cy}, radius, bg, border_w, border_color) do
    size = radius * 2
    x = cx - radius
    y = cy - radius

    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({x, y}, {size, size}, radius)
    |> Pdf.fill()
    |> maybe_border({x, y}, {size, size}, radius, border_w, border_color)
    |> Pdf.restore_state()
  end

  defp draw_circle(doc, {cx, cy}, content, bg, color, font, font_size, size, border_w, border_color) do
    radius = size / 2
    x = cx - radius
    y = cy - radius

    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({x, y}, {size, size}, radius)
    |> Pdf.fill()
    |> maybe_border({x, y}, {size, size}, radius, border_w, border_color)
    |> draw_centered_text({cx, cy}, content, color, font, font_size)
    |> Pdf.restore_state()
  end

  defp draw_pill(doc, {cx, cy}, content, bg, color, font, font_size, height, border_w, border_color) do
    radius = height / 2
    text_width = String.length(content) * font_size * 0.6
    pill_width = max(height, text_width + height * 0.6)
    x = cx - pill_width / 2
    y = cy - radius

    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(bg)
    |> Pdf.rounded_rectangle({x, y}, {pill_width, height}, radius)
    |> Pdf.fill()
    |> maybe_border({x, y}, {pill_width, height}, radius, border_w, border_color)
    |> draw_centered_text({cx, cy}, content, color, font, font_size)
    |> Pdf.restore_state()
  end

  # ── Border ─────────────────────────────────────────────────────

  defp maybe_border(doc, _pos, _size, _radius, 0, _color), do: doc

  defp maybe_border(doc, {x, y}, {w, h}, radius, width, color) do
    doc
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(width)
    |> Pdf.rounded_rectangle({x, y}, {w, h}, radius)
    |> Pdf.stroke()
  end

  # ── Text ───────────────────────────────────────────────────────

  defp draw_centered_text(doc, _center, "", _color, _font, _font_size), do: doc

  defp draw_centered_text(doc, {cx, cy}, text, color, font, font_size) do
    text_w = String.length(text) * font_size * 0.52
    tx = cx - text_w / 2
    ty = cy - font_size * 0.35

    doc
    |> Pdf.set_font(font, font_size)
    |> Pdf.set_fill_color(color)
    |> Pdf.text_at({tx, ty}, text)
  end
end
