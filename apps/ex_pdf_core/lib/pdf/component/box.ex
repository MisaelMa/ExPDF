defmodule Pdf.Component.Box do
  @moduledoc """
  Box component for PDF documents.

  Renders a rectangular container with optional padding, margin, border,
  border_radius, and background. Operates at Document level.

  ## Example

      doc
      |> Pdf.Component.Box.render({50, 700}, {300, 200}, %{
        padding: 10, border: 1, border_radius: 8, background: {0.95, 0.95, 1.0}
      }, fn doc, area ->
        Pdf.text_at(doc, {area.x + 5, area.y - 14}, "Inside the box")
      end)
  """

  alias Pdf.Style

  @doc """
  Render a box at `{x, y}` with size `{w, h}`, applying `style` options,
  then invoke `callback.(doc, inner_area)`.

  ## Style options

  - `:padding` — inner spacing (CSS shorthand: number, `{v, h}`, `{t, r, b, l}`)
  - `:margin` — outer spacing (CSS shorthand)
  - `:border` — border width (CSS shorthand)
  - `:border_color` — border color (default `:black`)
  - `:border_radius` — corner radius (default `0`)
  - `:background` — fill color (default `nil`)
  """
  def render(doc, {x, y}, {w, h}, style \\ %{}, callback) when is_function(callback, 2) do
    style = Style.new(style)
    {mt, mr, mb, ml} = style.margin
    {pt, pr, pb, pl} = style.padding
    {bt, br, bb, bl} = style.border
    r = style.border_radius

    outer_x = x + ml
    outer_y = y - mt
    outer_w = w - ml - mr
    outer_h = h - mt - mb

    # Draw background
    doc =
      if style.background do
        doc
        |> Pdf.save_state()
        |> Pdf.set_fill_color(style.background)
        |> draw_rect({outer_x, outer_y - outer_h}, {outer_w, outer_h}, r)
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        doc
      end

    # Draw border
    doc = draw_border(doc, {outer_x, outer_y, outer_w, outer_h}, style.border, style.border_color, r)

    # Compute inner area
    inner_x = outer_x + bl + pl
    inner_y = outer_y - bt - pt
    inner_w = outer_w - bl - br - pl - pr
    inner_h = outer_h - bt - bb - pt - pb

    callback.(doc, %{x: inner_x, y: inner_y, width: inner_w, height: inner_h})
  end

  defp draw_rect(doc, {x, y}, {w, h}, r) when r > 0 do
    Pdf.rounded_rectangle(doc, {x, y}, {w, h}, r)
  end

  defp draw_rect(doc, {x, y}, {w, h}, _r) do
    Pdf.rectangle(doc, {x, y}, {w, h})
  end

  defp draw_border(doc, {x, y, w, h}, {bt, br, bb, bl}, color, r) do
    has_border = bt > 0 or br > 0 or bb > 0 or bl > 0

    if has_border do
      # Use uniform border width (max of all sides) for rounded rects
      border_w = max(max(bt, br), max(bb, bl))

      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(color)
      |> Pdf.set_line_width(border_w)
      |> draw_rect({x, y - h}, {w, h}, r)
      |> Pdf.stroke()
      |> Pdf.restore_state()
    else
      doc
    end
  end
end
