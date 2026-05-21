defmodule Pdf.Component.Timeline do
  @moduledoc """
  Timeline component for PDF documents.

  Renders a vertical timeline with dots, connecting line, and event entries.
  Useful for CVs, project history, and changelogs.

  ## Examples

      doc |> Pdf.Component.Timeline.render({50, 700}, %{}, [
        %{date: "2026", title: "Launch", description: "Product released"},
        %{date: "2025", title: "Beta", description: "Beta testing phase"},
        %{date: "2024", title: "Founded", description: "Company started"}
      ])
  """

  @default_font "Helvetica"
  @default_font_size 10
  @default_color {0.1, 0.1, 0.1}
  @default_date_color {0.45, 0.45, 0.45}
  @default_line_color {0.8, 0.8, 0.8}
  @default_dot_color {0.2, 0.5, 0.9}
  @default_dot_size 6
  @default_row_height 50
  @default_date_width 60

  @doc """
  Render a timeline at `{x, y}`.

  ## Style options

  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — text size (default `10`)
  - `:color` — title/description color
  - `:date_color` — date text color
  - `:line_color` — vertical line color
  - `:dot_color` — dot fill color
  - `:dot_size` — dot diameter (default `6`)
  - `:row_height` — height per entry (default `50`)
  - `:date_width` — width reserved for dates (default `60`)

  ## Events format

  List of maps: `%{date: "2026", title: "Event", description: "Details"}`
  """
  def render(doc, {x, y}, style \\ %{}, events) do
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    date_color = Map.get(style, :date_color, @default_date_color)
    line_color = Map.get(style, :line_color, @default_line_color)
    dot_color = Map.get(style, :dot_color, @default_dot_color)
    dot_size = Map.get(style, :dot_size, @default_dot_size)
    row_height = Map.get(style, :row_height, @default_row_height)
    date_width = Map.get(style, :date_width, @default_date_width)

    dot_r = dot_size / 2
    line_x = x + date_width + dot_r
    text_x = line_x + dot_size + 8
    count = length(events)

    # Vertical line
    first_y = y - dot_r
    last_y = y - (count - 1) * row_height - dot_r

    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(line_color)
      |> Pdf.set_line_width(1.5)
      |> Pdf.line({line_x, first_y}, {line_x, last_y})
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # Events
    events
    |> Enum.with_index()
    |> Enum.reduce(doc, fn {event, i}, d ->
      ey = y - i * row_height
      dot_cy = ey - dot_r

      # Dot
      d =
        d
        |> Pdf.save_state()
        |> Pdf.set_fill_color(dot_color)
        |> Pdf.rounded_rectangle(
          {line_x - dot_r, dot_cy - dot_r},
          {dot_size, dot_size},
          dot_r
        )
        |> Pdf.fill()
        |> Pdf.restore_state()

      # Date
      date = Map.get(event, :date, "")
      d =
        d
        |> Pdf.set_font(font, font_size - 1)
        |> Pdf.set_fill_color(date_color)
        |> Pdf.text_at({x, dot_cy - 2}, date)

      # Title
      title = Map.get(event, :title, "")
      d =
        d
        |> Pdf.set_font(font, font_size, bold: true)
        |> Pdf.set_fill_color(color)
        |> Pdf.text_at({text_x, ey - 2}, title)

      # Description
      desc = Map.get(event, :description, "")
      if desc != "" do
        d
        |> Pdf.set_font(font, font_size - 1)
        |> Pdf.set_fill_color(date_color)
        |> Pdf.text_at({text_x, ey - 16}, desc)
      else
        d
      end
    end)
  end
end
