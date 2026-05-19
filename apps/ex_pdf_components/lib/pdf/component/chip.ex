defmodule Pdf.Component.Chip do
  @moduledoc """
  Chip component for PDF documents.

  Renders a compact rounded label/tag element, useful for displaying
  categories, tags, status indicators, or filter selections.

  Inspired by Material UI's Chip component.

  ## Examples

      # Simple chip
      doc |> Pdf.Component.Chip.render({50, 400}, %{label: "Elixir"})

      # Outlined chip
      doc |> Pdf.Component.Chip.render({50, 400}, %{
        label: "Active",
        variant: :outlined,
        color: {0.18, 0.72, 0.45}
      })

      # Filled chip with custom colors
      doc |> Pdf.Component.Chip.render({50, 400}, %{
        label: "Priority",
        background: {0.85, 0.26, 0.33},
        color: :white
      })
  """

  @default_height 24
  @default_background {0.92, 0.92, 0.92}
  @default_color {0.2, 0.2, 0.2}
  @default_font "Helvetica"
  @default_font_size 10
  @default_padding_h 10

  @doc """
  Render a chip at `{x, y}` (top-left corner).

  Returns `{doc, width}` — the document and the rendered chip width.

  ## Style options

  - `:label` — text to display (required)
  - `:variant` — `:filled` (default) or `:outlined`
  - `:background` — fill color for filled variant (default light gray)
  - `:color` — text/border color (default dark gray)
  - `:font` — font name (default `"Helvetica"`)
  - `:font_size` — font size (default `10`)
  - `:height` — chip height in points (default `24`)
  - `:padding_h` — horizontal padding (default `10`)
  - `:border` — border width for outlined variant (default `1`)
  """
  def render(doc, {x, y}, style \\ %{}) do
    label = Map.get(style, :label, "")
    variant = Map.get(style, :variant, :filled)
    bg = Map.get(style, :background, @default_background)
    color = Map.get(style, :color, @default_color)
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    height = Map.get(style, :height, @default_height)
    padding_h = Map.get(style, :padding_h, @default_padding_h)
    border_w = Map.get(style, :border, 1)

    # Estimate text width
    text_width = String.length(label) * font_size * 0.52
    chip_width = text_width + padding_h * 2
    radius = height / 2

    # Position: {x, y} is top-left, PDF y is bottom-left
    bx = x
    by = y - height

    doc = Pdf.save_state(doc)

    doc = case variant do
      :outlined ->
        doc
        |> Pdf.set_stroke_color(color)
        |> Pdf.set_line_width(border_w)
        |> Pdf.rounded_rectangle({bx, by}, {chip_width, height}, radius)
        |> Pdf.stroke()

      _filled ->
        doc
        |> Pdf.set_fill_color(bg)
        |> Pdf.rounded_rectangle({bx, by}, {chip_width, height}, radius)
        |> Pdf.fill()
    end

    # Center text vertically
    tx = bx + padding_h
    ty = by + (height - font_size) / 2 + font_size * 0.15

    doc = doc
    |> Pdf.set_font(font, font_size)
    |> Pdf.set_fill_color(color)
    |> Pdf.text_at({tx, ty}, label)
    |> Pdf.restore_state()

    {doc, chip_width}
  end
end
