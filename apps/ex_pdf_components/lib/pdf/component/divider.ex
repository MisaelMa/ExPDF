defmodule Pdf.Component.Divider do
  @moduledoc """
  Divider component for PDF documents.

  Renders a horizontal or vertical line separator with configurable
  color, width, style (solid/dashed), and margin.

  Inspired by Material UI's Divider component.

  ## Examples

      # Simple horizontal divider
      doc |> Pdf.Component.Divider.render({50, 400}, %{width: 200})

      # Dashed divider with color
      doc |> Pdf.Component.Divider.render({50, 400}, %{
        width: 200,
        color: {0.8, 0.8, 0.8},
        style: :dashed,
        thickness: 0.5
      })

      # Vertical divider
      doc |> Pdf.Component.Divider.render({250, 700}, %{
        height: 100,
        orientation: :vertical
      })
  """

  @default_color {0.85, 0.85, 0.85}
  @default_thickness 0.5
  @default_dash_pattern {3, 3}

  @doc """
  Render a divider at `{x, y}`.

  ## Style options

  - `:width` — length for horizontal dividers (default `0`, required for horizontal)
  - `:height` — length for vertical dividers (default `0`, required for vertical)
  - `:orientation` — `:horizontal` (default) or `:vertical`
  - `:color` — line color (default light gray)
  - `:thickness` — line width in points (default `0.5`)
  - `:style` — `:solid` (default) or `:dashed`
  - `:dash` — custom dash pattern `{on, off}` (default `{3, 3}`)
  - `:margin_top` — space above (default `0`)
  - `:margin_bottom` — space below (default `0`)
  """
  def render(doc, {x, y}, style \\ %{}) do
    orientation = Map.get(style, :orientation, :horizontal)
    color = Map.get(style, :color, @default_color)
    thickness = Map.get(style, :thickness, @default_thickness)
    line_style = Map.get(style, :style, :solid)
    margin_top = Map.get(style, :margin_top, 0)
    margin_bottom = Map.get(style, :margin_bottom, 0)

    y = y - margin_top

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(thickness)

    doc = apply_dash(doc, line_style, Map.get(style, :dash, @default_dash_pattern))

    doc = case orientation do
      :vertical ->
        h = Map.get(style, :height, 0)
        Pdf.line(doc, {x, y}, {x, y - h})

      _horizontal ->
        w = Map.get(style, :width, 0)
        Pdf.line(doc, {x, y}, {x + w, y})
    end

    doc = Pdf.restore_state(doc)

    if margin_bottom > 0 do
      Pdf.spacer(doc, margin_bottom)
    else
      doc
    end
  end

  defp apply_dash(doc, :solid, _pattern), do: doc

  defp apply_dash(doc, :dashed, {on, off}) do
    Pdf.set_dash(doc, [on, off])
  end
end
