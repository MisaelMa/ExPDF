defmodule Pdf.Component.Blockquote do
  @moduledoc """
  Blockquote component for PDF documents.

  Renders an indented text block with a colored left bar,
  optional background, and citation line.

  ## Examples

      doc |> Pdf.Component.Blockquote.render({50, 700}, %{width: 400},
        "The best way to predict the future is to invent it.")

      doc |> Pdf.Component.Blockquote.render({50, 700}, %{
        width: 400,
        bar_color: {0.2, 0.5, 0.8},
        cite: "— Alan Kay"
      }, "The best way to predict the future is to invent it.")
  """

  @default_bar_color {0.75, 0.75, 0.75}
  @default_bar_width 3
  @default_padding 12
  @default_font "Helvetica"
  @default_font_size 10
  @default_color {0.25, 0.25, 0.25}
  @default_cite_color {0.5, 0.5, 0.5}
  @default_bg nil

  @doc """
  Render a blockquote at `{x, y}`.

  ## Style options

  - `:width` — total width of the blockquote (required)
  - `:bar_color` — left accent bar color (default gray)
  - `:bar_width` — bar thickness (default `3`)
  - `:background` — optional background color
  - `:padding` — inner padding (default `12`)
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — text size (default `10`)
  - `:color` — text color (default dark gray)
  - `:italic` — render text in italic (default `true`)
  - `:cite` — optional citation line below the quote
  - `:cite_color` — citation text color (default lighter gray)
  """
  def render(doc, {x, y}, style \\ %{}, text) do
    width = Map.get(style, :width, 400)
    bar_color = Map.get(style, :bar_color, @default_bar_color)
    bar_width = Map.get(style, :bar_width, @default_bar_width)
    bg = Map.get(style, :background, @default_bg)
    padding = Map.get(style, :padding, @default_padding)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    italic = Map.get(style, :italic, true)
    cite = Map.get(style, :cite)
    cite_color = Map.get(style, :cite_color, @default_cite_color)

    line_height = font_size * 1.5
    text_x = x + bar_width + padding

    # Estimate height: wrap text manually by character count
    avail_w = width - bar_width - padding * 2
    chars_per_line = max(trunc(avail_w / (font_size * 0.52)), 10)
    lines = wrap_text(text, chars_per_line)
    text_h = length(lines) * line_height
    cite_h = if cite, do: line_height + 4, else: 0
    total_h = padding + text_h + cite_h + padding

    # Background
    doc =
      if bg do
        doc
        |> Pdf.save_state()
        |> Pdf.set_fill_color(bg)
        |> Pdf.rectangle({x, y - total_h}, {width, total_h})
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        doc
      end

    # Left bar
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(bar_color)
      |> Pdf.rectangle({x, y - total_h}, {bar_width, total_h})
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Text lines
    font_opts = if italic, do: [italic: true], else: []

    doc =
      doc
      |> Pdf.set_font(font, font_size, font_opts)
      |> Pdf.set_fill_color(color)

    {doc, last_y} =
      Enum.reduce(lines, {doc, y - padding - font_size}, fn line, {d, ly} ->
        d2 = Pdf.text_at(d, {text_x, ly}, line)
        {d2, ly - line_height}
      end)

    # Citation
    doc =
      if cite do
        doc
        |> Pdf.set_font(font, font_size - 1)
        |> Pdf.set_fill_color(cite_color)
        |> Pdf.text_at({text_x, last_y - 4}, cite)
      else
        doc
      end

    doc
  end

  defp wrap_text(text, chars_per_line) do
    words = String.split(text, " ")

    {lines, current} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        if String.length(candidate) > chars_per_line and current != "" do
          {[current | lines], word}
        else
          {lines, candidate}
        end
      end)

    Enum.reverse(if current != "", do: [current | lines], else: lines)
  end
end
