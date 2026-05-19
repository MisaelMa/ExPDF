defmodule Pdf.Component.KeyValue do
  @moduledoc """
  Key-value pair component for PDF documents.

  Renders aligned label-value rows, like invoice details or profile info.

  ## Examples

      doc |> Pdf.Component.KeyValue.render({50, 700}, %{width: 300}, [
        {"Name:", "John Doe"},
        {"Email:", "john@example.com"},
        {"Role:", "Admin"}
      ])
  """

  @default_font "Helvetica"
  @default_font_size 10
  @default_label_color {0.35, 0.35, 0.35}
  @default_value_color {0.1, 0.1, 0.1}
  @default_line_height 18
  @default_label_width 0.35

  @doc """
  Render key-value pairs at `{x, y}`.

  ## Style options

  - `:width` — total width (default `300`)
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — text size (default `10`)
  - `:label_color` — label text color
  - `:value_color` — value text color
  - `:line_height` — row spacing (default `18`)
  - `:label_width` — fraction of width for labels (default `0.35`)
  - `:divider` — show divider between rows (default `false`)
  - `:divider_color` — divider line color
  - `:striped` — alternate row backgrounds (default `false`)
  - `:stripe_color` — background for even rows
  - `:value_align` — `:left` (default) or `:right` to right-align values
  - `:label_bold` — bold labels (default `true`)
  - `:value_bold` — bold values (default `false`)
  """
  def render(doc, {x, y}, style \\ %{}, pairs) do
    width = Map.get(style, :width, 300)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    label_color = Map.get(style, :label_color, @default_label_color)
    value_color = Map.get(style, :value_color, @default_value_color)
    line_height = Map.get(style, :line_height, @default_line_height)
    label_w = trunc(width * Map.get(style, :label_width, @default_label_width))
    divider = Map.get(style, :divider, false)
    divider_color = Map.get(style, :divider_color, {0.9, 0.9, 0.9})
    striped = Map.get(style, :striped, false)
    stripe_color = Map.get(style, :stripe_color, {0.97, 0.97, 0.97})
    value_align = Map.get(style, :value_align, :left)
    label_bold = Map.get(style, :label_bold, true)
    value_bold = Map.get(style, :value_bold, false)

    font_struct = Pdf.Fonts.get_internal_font(font, if(value_bold, do: [bold: true], else: []))

    pairs
    |> Enum.with_index()
    |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      row_y = y - i * line_height

      # Stripe background
      d =
        if striped and rem(i, 2) == 0 do
          d
          |> Pdf.save_state()
          |> Pdf.set_fill_color(stripe_color)
          |> Pdf.rectangle({x, row_y - line_height + font_size + 2}, {width, line_height})
          |> Pdf.fill()
          |> Pdf.restore_state()
        else
          d
        end

      # Divider
      d =
        if divider and i > 0 do
          d
          |> Pdf.save_state()
          |> Pdf.set_stroke_color(divider_color)
          |> Pdf.set_line_width(0.3)
          |> Pdf.line({x, row_y + line_height - font_size - 2}, {x + width, row_y + line_height - font_size - 2})
          |> Pdf.stroke()
          |> Pdf.restore_state()
        else
          d
        end

      value_x =
        case value_align do
          :right ->
            vf = font_struct || Pdf.Fonts.get_internal_font(font)
            tw = if vf, do: Pdf.Font.text_width(vf, value, font_size), else: 0
            x + width - tw
          _ ->
            x + label_w
        end

      d
      |> Pdf.set_font(font, font_size, bold: label_bold)
      |> Pdf.set_fill_color(label_color)
      |> Pdf.text_at({x, row_y}, label)
      |> Pdf.set_font(font, font_size, bold: value_bold)
      |> Pdf.set_fill_color(value_color)
      |> Pdf.text_at({value_x, row_y}, value)
    end)
  end
end
