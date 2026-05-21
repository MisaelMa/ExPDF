defmodule Pdf.Component.Rating do
  @moduledoc """
  Rating component for PDF documents.

  Renders a star/score rating display with filled and empty indicators.

  ## Examples

      doc |> Pdf.Component.Rating.render({50, 700}, %{value: 4, max: 5})

      doc |> Pdf.Component.Rating.render({50, 700}, %{
        value: 3.5,
        max: 5,
        filled_color: {0.95, 0.7, 0.0},
        size: 16
      })
  """

  @default_size 14
  @default_max 5
  @default_filled_color {0.95, 0.7, 0.0}
  @default_empty_color {0.82, 0.82, 0.82}
  @default_font "Helvetica"
  @default_gap 4
  @default_label_color {0.3, 0.3, 0.3}

  @doc """
  Render a rating at `{x, y}`.

  ## Style options

  - `:value` — current score (default `0`)
  - `:max` — maximum score (default `5`)
  - `:size` — star size (default `14`)
  - `:filled_color` — filled star color (default gold)
  - `:empty_color` — empty star color (default light gray)
  - `:gap` — space between stars (default `4`)
  - `:show_label` — show "3.5/5" text (default `false`)
  - `:label_color` — label text color
  """
  def render(doc, {x, y}, style \\ %{}) do
    value = Map.get(style, :value, 0)
    max = Map.get(style, :max, @default_max)
    size = Map.get(style, :size, @default_size)
    filled = Map.get(style, :filled_color, @default_filled_color)
    empty = Map.get(style, :empty_color, @default_empty_color)
    gap = Map.get(style, :gap, @default_gap)
    font = Map.get(style, :font, @default_font)
    show_label = Map.get(style, :show_label, false)
    label_color = Map.get(style, :label_color, @default_label_color)

    r = size / 2

    doc =
      Enum.reduce(0..(max - 1), doc, fn i, d ->
        sx = x + i * (size + gap)
        color = if i < trunc(value), do: filled, else: empty

        d
        |> Pdf.save_state()
        |> Pdf.set_fill_color(color)
        |> Pdf.rounded_rectangle({sx, y - size}, {size, size}, r)
        |> Pdf.fill()
        |> Pdf.restore_state()
      end)

    # Half star: overlay a partial fill if value has decimal
    frac = value - trunc(value)
    doc =
      if frac > 0 do
        half_i = trunc(value)
        sx = x + half_i * (size + gap)
        half_w = size * frac

        doc
        |> Pdf.save_state()
        |> Pdf.set_fill_color(filled)
        |> Pdf.rectangle({sx, y - size}, {half_w, size})
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        doc
      end

    if show_label do
      label_x = x + max * (size + gap) + 4
      label = if frac > 0, do: "#{value}/#{max}", else: "#{trunc(value)}/#{max}"

      doc
      |> Pdf.set_font(font, size - 2)
      |> Pdf.set_fill_color(label_color)
      |> Pdf.text_at({label_x, y - size + 2}, label)
    else
      doc
    end
  end
end
