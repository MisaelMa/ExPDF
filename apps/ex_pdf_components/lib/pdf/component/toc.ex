defmodule Pdf.Component.TOC do
  @moduledoc """
  Table of Contents component for PDF documents.

  Renders a list of entries with titles, optional dot leaders,
  and right-aligned page numbers.

  ## Examples

      doc |> Pdf.Component.TOC.render({50, 700}, %{width: 450}, [
        %{title: "Introduction", page: 1},
        %{title: "Getting Started", page: 3, level: 1},
        %{title: "Installation", page: 3, level: 2},
        %{title: "Configuration", page: 5, level: 2},
        %{title: "Advanced Usage", page: 10, level: 1}
      ])
  """

  @default_font "Helvetica"
  @default_font_size 10
  @default_color {0.1, 0.1, 0.1}
  @default_page_color {0.4, 0.4, 0.4}
  @default_dot_color {0.7, 0.7, 0.7}
  @default_line_height 18
  @default_indent 20

  @doc """
  Render a table of contents at `{x, y}`.

  ## Style options

  - `:width` — total width (default `450`)
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — base text size (default `10`)
  - `:color` — title text color
  - `:page_color` — page number color
  - `:dot_color` — dot leader color
  - `:line_height` — row spacing (default `18`)
  - `:indent` — indentation per level (default `20`)
  - `:dots` — show dot leaders (default `true`)

  ## Entries format

  List of maps: `%{title: "Section", page: 1, level: 1}`
  Level defaults to `1`. Level `0` renders bold (chapter heading).
  """
  def render(doc, {x, y}, style \\ %{}, entries) do
    width = Map.get(style, :width, 450)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    page_color = Map.get(style, :page_color, @default_page_color)
    dot_color = Map.get(style, :dot_color, @default_dot_color)
    line_height = Map.get(style, :line_height, @default_line_height)
    indent = Map.get(style, :indent, @default_indent)
    dots = Map.get(style, :dots, true)

    entries
    |> Enum.with_index()
    |> Enum.reduce(doc, fn {entry, i}, d ->
      level = Map.get(entry, :level, 1)
      title = Map.get(entry, :title, "")
      page = Map.get(entry, :page, "")
      page_str = "#{page}"

      ey = y - i * line_height
      entry_x = x + (level - 0) * indent
      is_heading = level == 0

      fs = if is_heading, do: font_size + 1, else: font_size
      font_opts = if is_heading, do: [bold: true], else: []

      # Title
      d =
        d
        |> Pdf.set_font(font, fs, font_opts)
        |> Pdf.set_fill_color(color)
        |> Pdf.text_at({entry_x, ey}, title)

      # Page number (right-aligned)
      page_w = String.length(page_str) * fs * 0.55
      page_x = x + width - page_w

      d =
        d
        |> Pdf.set_font(font, fs)
        |> Pdf.set_fill_color(page_color)
        |> Pdf.text_at({page_x, ey}, page_str)

      # Dot leaders
      if dots and not is_heading do
        title_w = String.length(title) * fs * 0.52
        dot_start = entry_x + title_w + 4
        dot_end = page_x - 4
        dot_spacing = 4

        if dot_end > dot_start do
          dots_count = trunc((dot_end - dot_start) / dot_spacing)
          dot_text = String.duplicate(". ", dots_count)

          d
          |> Pdf.set_font(font, fs - 2)
          |> Pdf.set_fill_color(dot_color)
          |> Pdf.text_at({dot_start, ey}, dot_text)
        else
          d
        end
      else
        d
      end
    end)
  end
end
