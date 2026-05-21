defmodule Pdf.Component.Footnote do
  @moduledoc """
  Footnote component for PDF documents.

  Renders footnotes at a given position with a separator line,
  superscript numbers, and smaller text.

  ## Examples

      doc |> Pdf.Component.Footnote.render({50, 100}, %{width: 450}, [
        "Source: World Bank Data, 2025",
        "All figures adjusted for inflation",
        "Excluding outlier regions"
      ])
  """

  @default_font "Helvetica"
  @default_font_size 7
  @default_color {0.4, 0.4, 0.4}
  @default_line_color {0.75, 0.75, 0.75}
  @default_line_height 11
  @default_separator_width 80

  @doc """
  Render footnotes at `{x, y}`.

  ## Style options

  - `:width` — available width (default `450`)
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — text size (default `7`)
  - `:color` — text color
  - `:line_color` — separator line color
  - `:line_height` — spacing between notes (default `11`)
  - `:separator_width` — width of the top separator line (default `80`)
  - `:start_number` — first footnote number (default `1`)
  """
  def render(doc, {x, y}, style \\ %{}, notes) do
    _width = Map.get(style, :width, 450)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    line_color = Map.get(style, :line_color, @default_line_color)
    line_height = Map.get(style, :line_height, @default_line_height)
    sep_width = Map.get(style, :separator_width, @default_separator_width)
    start_num = Map.get(style, :start_number, 1)

    # Separator line
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(line_color)
      |> Pdf.set_line_width(0.5)
      |> Pdf.line({x, y}, {x + sep_width, y})
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # Footnote entries
    notes
    |> Enum.with_index(start_num)
    |> Enum.reduce(doc, fn {note, num}, d ->
      ny = y - 8 - (num - start_num) * line_height
      num_text = "#{num}"
      num_w = String.length(num_text) * (font_size - 1) * 0.55

      d
      |> Pdf.set_font(font, font_size - 1)
      |> Pdf.set_fill_color(color)
      |> Pdf.text_at({x, ny + 2}, num_text)
      |> Pdf.set_font(font, font_size)
      |> Pdf.set_fill_color(color)
      |> Pdf.text_at({x + num_w + 3, ny}, note)
    end)
  end
end
