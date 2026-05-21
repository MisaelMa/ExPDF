defmodule Pdf.Component.Progress do
  @moduledoc """
  Progress bar component for PDF documents.

  Renders a horizontal progress/percentage bar with track and fill,
  optional label, and rounded or square ends.

  Inspired by Material UI's LinearProgress component.

  ## Examples

      # Simple progress bar
      doc |> Pdf.Component.Progress.render({50, 400}, %{width: 200, value: 75})

      # Styled progress bar with label
      doc |> Pdf.Component.Progress.render({50, 400}, %{
        width: 300,
        value: 42,
        color: {0.18, 0.72, 0.45},
        show_label: true,
        height: 16,
        border_radius: :rounded
      })
  """

  @default_width 200
  @default_height 8
  @default_color {0.23, 0.53, 0.88}
  @default_track_color {0.92, 0.92, 0.92}
  @default_font "Helvetica"

  @doc """
  Render a progress bar at `{x, y}` (top-left corner).

  ## Style options

  - `:width` — total bar width (default `200`)
  - `:height` — bar height (default `8`)
  - `:value` — progress percentage 0-100 (default `0`)
  - `:color` — fill color (default blue)
  - `:track_color` — background track color (default light gray)
  - `:border_radius` — `:rounded` (default), `:square`, or number
  - `:show_label` — show percentage text (default `false`)
  - `:label_color` — text color for label (default dark gray)
  - `:font` — font name (default `"Helvetica"`)
  """
  def render(doc, {x, y}, style \\ %{}) do
    width = Map.get(style, :width, @default_width)
    height = Map.get(style, :height, @default_height)
    value = Map.get(style, :value, 0) |> max(0) |> min(100)
    color = Map.get(style, :color, @default_color)
    track_color = Map.get(style, :track_color, @default_track_color)
    border_radius = resolve_radius(Map.get(style, :border_radius, :rounded), height)
    show_label = Map.get(style, :show_label, false)
    label_color = Map.get(style, :label_color, {0.3, 0.3, 0.3})
    font = Map.get(style, :font, @default_font)

    # PDF coords: y is bottom-left
    by = y - height
    fill_width = width * value / 100

    doc = doc
    |> Pdf.save_state()
    # Track (background)
    |> Pdf.set_fill_color(track_color)
    |> Pdf.rounded_rectangle({x, by}, {width, height}, border_radius)
    |> Pdf.fill()

    # Fill (progress)
    doc = if fill_width > 0 do
      # Clamp radius so it doesn't exceed fill width
      fill_radius = min(border_radius, fill_width / 2)
      doc
      |> Pdf.set_fill_color(color)
      |> Pdf.rounded_rectangle({x, by}, {fill_width, height}, fill_radius)
      |> Pdf.fill()
    else
      doc
    end

    doc = Pdf.restore_state(doc)

    # Label
    if show_label do
      label = "#{round(value)}%"
      font_size = min(height * 0.75, 10)
      label_x = x + width + 6
      label_y = by + (height - font_size) / 2 + font_size * 0.15

      doc
      |> Pdf.save_state()
      |> Pdf.set_font(font, font_size)
      |> Pdf.set_fill_color(label_color)
      |> Pdf.text_at({label_x, label_y}, label)
      |> Pdf.restore_state()
    else
      doc
    end
  end

  defp resolve_radius(:rounded, height), do: height / 2
  defp resolve_radius(:square, _height), do: 0
  defp resolve_radius(n, _height) when is_number(n), do: n
  defp resolve_radius(_, height), do: height / 2
end
