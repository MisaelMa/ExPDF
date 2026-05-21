defmodule Pdf.Component.Metric do
  @moduledoc """
  Metric comparison component for PDF documents.

  Renders a before/after or current vs previous value with delta indicator.
  Useful for reports and dashboards.

  ## Examples

      doc |> Pdf.Component.Metric.render({50, 700}, %{
        label: "Revenue",
        current: "$12,450",
        previous: "$10,200",
        delta: "+22%",
        delta_direction: :up
      })
  """

  @default_font "Helvetica"
  @default_width 200
  @default_label_color {0.45, 0.45, 0.45}
  @default_value_color {0.1, 0.1, 0.1}
  @default_up_color {0.2, 0.7, 0.3}
  @default_down_color {0.8, 0.2, 0.2}
  @default_neutral_color {0.5, 0.5, 0.5}

  @doc """
  Render a metric at `{x, y}`.

  ## Style options

  - `:label` — metric name
  - `:current` — current/primary value (large)
  - `:previous` — previous value (small, muted)
  - `:delta` — change string (e.g. "+22%")
  - `:delta_direction` — `:up`, `:down`, or `:neutral`
  - `:width` — component width (default `200`)
  - `:font` — font name
  - `:background` — optional background color
  - `:border_radius` — corner radius (default `6`)
  """
  def render(doc, {x, y}, style \\ %{}) do
    label = Map.get(style, :label, "")
    current = Map.get(style, :current, "0")
    previous = Map.get(style, :previous)
    delta = Map.get(style, :delta)
    direction = Map.get(style, :delta_direction, :neutral)
    width = Map.get(style, :width, @default_width)
    font = Map.get(style, :font, @default_font)
    label_color = Map.get(style, :label_color, @default_label_color)
    value_color = Map.get(style, :value_color, @default_value_color)
    bg = Map.get(style, :background)
    radius = Map.get(style, :border_radius, 6)

    height = 70
    padding = 10

    delta_color = case direction do
      :up -> Map.get(style, :up_color, @default_up_color)
      :down -> Map.get(style, :down_color, @default_down_color)
      _ -> Map.get(style, :neutral_color, @default_neutral_color)
    end

    # Background
    doc =
      if bg do
        doc
        |> Pdf.save_state()
        |> Pdf.set_fill_color(bg)
        |> Pdf.rounded_rectangle({x, y - height}, {width, height}, radius)
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        doc
      end

    # Label
    doc =
      doc
      |> Pdf.set_font(font, 9)
      |> Pdf.set_fill_color(label_color)
      |> Pdf.text_at({x + padding, y - 14}, label)

    # Current value (large)
    doc =
      doc
      |> Pdf.set_font(font, 20, bold: true)
      |> Pdf.set_fill_color(value_color)
      |> Pdf.text_at({x + padding, y - 38}, current)

    # Delta
    doc =
      if delta do
        arrow = case direction do
          :up -> "^ "
          :down -> "v "
          _ -> ""
        end
        doc
        |> Pdf.set_font(font, 10, bold: true)
        |> Pdf.set_fill_color(delta_color)
        |> Pdf.text_at({x + padding, y - 56}, arrow <> delta)
      else
        doc
      end

    # Previous value
    if previous do
      prev_text = "vs #{previous}"
      prev_w = String.length(prev_text) * 9 * 0.5
      doc
      |> Pdf.set_font(font, 9)
      |> Pdf.set_fill_color(label_color)
      |> Pdf.text_at({x + width - padding - prev_w, y - 56}, prev_text)
    else
      doc
    end
  end
end
