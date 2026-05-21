defmodule Pdf.Component.StatCard do
  @moduledoc """
  Stat card component for PDF documents.

  Renders a dashboard-style KPI card with a large number/value,
  a label, and optional trend indicator. Useful for reports and dashboards.

  ## Examples

      doc |> Pdf.Component.StatCard.render({50, 700}, %{
        value: "$12,450",
        label: "Monthly Revenue",
        width: 150
      })

      doc |> Pdf.Component.StatCard.render({50, 700}, %{
        value: "98.5%",
        label: "Uptime",
        trend: "+2.1%",
        trend_color: {0.2, 0.7, 0.3},
        accent_color: {0.2, 0.5, 0.9}
      })
  """

  @default_width 150
  @default_height 90
  @default_background {1.0, 1.0, 1.0}
  @default_accent_color {0.2, 0.5, 0.9}
  @default_value_color {0.1, 0.1, 0.1}
  @default_label_color {0.5, 0.5, 0.5}
  @default_border_radius 6
  @default_font "Helvetica"

  @doc """
  Render a stat card at `{x, y}` (top-left).

  ## Style options

  - `:value` — the main number/text (required)
  - `:label` — description below the value
  - `:trend` — optional trend string (e.g. "+5.2%")
  - `:trend_color` — color for the trend text
  - `:width` — card width (default `150`)
  - `:height` — card height (default `90`)
  - `:background` — card background (default white)
  - `:accent_color` — top accent bar color (default blue)
  - `:value_color` — value text color
  - `:label_color` — label text color
  - `:border_radius` — corner radius (default `6`)
  - `:border` — border width (default `0.5`)
  - `:border_color` — border color
  """
  def render(doc, {x, y}, style \\ %{}) do
    value = Map.get(style, :value, "0")
    label = Map.get(style, :label, "")
    trend = Map.get(style, :trend)
    trend_color = Map.get(style, :trend_color, {0.2, 0.7, 0.3})
    width = Map.get(style, :width, @default_width)
    height = Map.get(style, :height, @default_height)
    bg = Map.get(style, :background, @default_background)
    accent = Map.get(style, :accent_color, @default_accent_color)
    value_color = Map.get(style, :value_color, @default_value_color)
    label_color = Map.get(style, :label_color, @default_label_color)
    radius = Map.get(style, :border_radius, @default_border_radius)
    border_w = Map.get(style, :border, 0.5)
    border_color = Map.get(style, :border_color, {0.88, 0.88, 0.88})
    font = Map.get(style, :font, @default_font)

    by = y - height
    accent_h = 4

    # Background
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(bg)
      |> Pdf.rounded_rectangle({x, by}, {width, height}, radius)
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Top accent bar
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(accent)
      |> Pdf.rectangle({x + 1, y - accent_h}, {width - 2, accent_h})
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Border
    doc =
      if border_w > 0 do
        doc
        |> Pdf.save_state()
        |> Pdf.set_stroke_color(border_color)
        |> Pdf.set_line_width(border_w)
        |> Pdf.rounded_rectangle({x, by}, {width, height}, radius)
        |> Pdf.stroke()
        |> Pdf.restore_state()
      else
        doc
      end

    # Value (large)
    value_size = if String.length(value) > 8, do: 18, else: 22

    doc =
      doc
      |> Pdf.set_font(font, value_size, bold: true)
      |> Pdf.set_fill_color(value_color)
      |> Pdf.text_at({x + 12, y - accent_h - value_size - 6}, value)

    # Trend (next to value)
    doc =
      if trend do
        value_w = String.length(value) * value_size * 0.55
        doc
        |> Pdf.set_font(font, 10)
        |> Pdf.set_fill_color(trend_color)
        |> Pdf.text_at({x + 12 + value_w + 6, y - accent_h - value_size - 4}, trend)
      else
        doc
      end

    # Label
    doc
    |> Pdf.set_font(font, 9)
    |> Pdf.set_fill_color(label_color)
    |> Pdf.text_at({x + 12, by + 12}, label)
  end
end
