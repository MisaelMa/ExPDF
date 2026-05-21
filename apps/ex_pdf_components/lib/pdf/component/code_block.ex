defmodule Pdf.Component.CodeBlock do
  @moduledoc """
  Code block component for PDF documents.

  Renders monospaced text with a background box, optional line numbers,
  and syntax-like styling. Designed for code snippets and terminal output.

  ## Examples

      doc |> Pdf.Component.CodeBlock.render({50, 700}, %{width: 400},
        "defmodule Hello do\\n  def world, do: :ok\\nend")

      doc |> Pdf.Component.CodeBlock.render({50, 700}, %{
        width: 400,
        line_numbers: true,
        background: {0.15, 0.15, 0.18}
        color: {0.9, 0.9, 0.9}
      }, code)
  """

  @default_font "Courier"
  @default_font_size 9
  @default_color {0.2, 0.2, 0.2}
  @default_background {0.95, 0.96, 0.97}
  @default_border_color {0.85, 0.85, 0.85}
  @default_padding 10
  @default_line_height 13
  @default_border_radius 4

  @doc """
  Render a code block at `{x, y}`.

  ## Style options

  - `:width` — block width (required)
  - `:font` — monospaced font (default `"Courier"`)
  - `:font_size` — text size (default `9`)
  - `:color` — text color (default dark)
  - `:background` — background color (default light gray)
  - `:border_color` — border color (default gray)
  - `:border_radius` — corner radius (default `4`)
  - `:padding` — inner padding (default `10`)
  - `:line_height` — spacing between lines (default `13`)
  - `:line_numbers` — show line numbers (default `false`)
  - `:line_number_color` — line number color (default muted)
  - `:title` — optional title/filename above the block
  """
  def render(doc, {x, y}, style \\ %{}, code) do
    width = Map.get(style, :width, 400)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    color = Map.get(style, :color, @default_color)
    bg = Map.get(style, :background, @default_background)
    border_color = Map.get(style, :border_color, @default_border_color)
    border_radius = Map.get(style, :border_radius, @default_border_radius)
    padding = Map.get(style, :padding, @default_padding)
    line_height = Map.get(style, :line_height, @default_line_height)
    line_numbers = Map.get(style, :line_numbers, false)
    ln_color = Map.get(style, :line_number_color, {0.6, 0.6, 0.6})
    title = Map.get(style, :title)

    lines = String.split(code, "\n")
    ln_width = if line_numbers, do: String.length("#{length(lines)}") * font_size * 0.6 + 12, else: 0

    title_h = if title, do: font_size + padding, else: 0
    total_h = title_h + padding + length(lines) * line_height + padding

    # Background
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_fill_color(bg)
      |> Pdf.rounded_rectangle({x, y - total_h}, {width, total_h}, border_radius)
      |> Pdf.fill()
      |> Pdf.restore_state()

    # Border
    doc =
      doc
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(border_color)
      |> Pdf.set_line_width(0.5)
      |> Pdf.rounded_rectangle({x, y - total_h}, {width, total_h}, border_radius)
      |> Pdf.stroke()
      |> Pdf.restore_state()

    # Title bar
    {doc, content_y} =
      if title do
        title_y = y - font_size - 2

        doc =
          doc
          |> Pdf.save_state()
          |> Pdf.set_stroke_color(border_color)
          |> Pdf.set_line_width(0.5)
          |> Pdf.line({x, y - title_h}, {x + width, y - title_h})
          |> Pdf.stroke()
          |> Pdf.restore_state()
          |> Pdf.set_font("Helvetica", font_size, bold: true)
          |> Pdf.set_fill_color(color)
          |> Pdf.text_at({x + padding, title_y}, title)

        {doc, y - title_h}
      else
        {doc, y}
      end

    # Line number separator
    doc =
      if line_numbers and ln_width > 0 do
        sep_x = x + ln_width + 4
        doc
        |> Pdf.save_state()
        |> Pdf.set_stroke_color(border_color)
        |> Pdf.set_line_width(0.3)
        |> Pdf.line({sep_x, content_y - 4}, {sep_x, y - total_h + 4})
        |> Pdf.stroke()
        |> Pdf.restore_state()
      else
        doc
      end

    # Code lines
    text_x = x + padding + ln_width + (if line_numbers, do: 8, else: 0)
    start_y = content_y - padding - font_size

    lines
    |> Enum.with_index(1)
    |> Enum.reduce(doc, fn {line, num}, d ->
      ly = start_y - (num - 1) * line_height

      d =
        if line_numbers do
          ln_text = String.pad_leading("#{num}", String.length("#{length(lines)}"))
          d
          |> Pdf.set_font(font, font_size)
          |> Pdf.set_fill_color(ln_color)
          |> Pdf.text_at({x + padding, ly}, ln_text)
        else
          d
        end

      d
      |> Pdf.set_font(font, font_size)
      |> Pdf.set_fill_color(color)
      |> Pdf.text_at({text_x, ly}, line)
    end)
  end
end
