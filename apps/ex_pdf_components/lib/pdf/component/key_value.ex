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

    value_w = width - label_w
    vf = font_struct || Pdf.Fonts.get_internal_font(font)

    ctx = %{
      x: x, width: width, font: font, font_size: font_size,
      label_color: label_color, value_color: value_color,
      line_height: line_height, label_w: label_w, value_w: value_w,
      divider: divider, divider_color: divider_color,
      striped: striped, stripe_color: stripe_color,
      value_align: value_align, label_bold: label_bold, value_bold: value_bold,
      vf: vf
    }

    {doc, _cy} =
      pairs
      |> Enum.with_index()
      |> Enum.reduce({doc, y}, fn {{label, value}, i}, {d, current_y} ->
        row_y = current_y

        # Stripe background
        d =
          if ctx.striped and rem(i, 2) == 0 do
            d
            |> Pdf.save_state()
            |> Pdf.set_fill_color(ctx.stripe_color)
            |> Pdf.rectangle({x, row_y - line_height + font_size + 2}, {width, line_height})
            |> Pdf.fill()
            |> Pdf.restore_state()
          else
            d
          end

        # Divider
        d =
          if ctx.divider and i > 0 do
            d
            |> Pdf.save_state()
            |> Pdf.set_stroke_color(ctx.divider_color)
            |> Pdf.set_line_width(0.3)
            |> Pdf.line({x, row_y + line_height - font_size - 2}, {x + width, row_y + line_height - font_size - 2})
            |> Pdf.stroke()
            |> Pdf.restore_state()
          else
            d
          end

        # Wrap value into lines
        lines = wrap_value(value, vf, font_size, value_w)

        # Render label on first line
        d =
          d
          |> Pdf.set_font(font, font_size, bold: label_bold)
          |> Pdf.set_fill_color(label_color)
          |> Pdf.text_at({x, row_y}, label)

        # Render value lines
        {d, _ly} =
          Enum.reduce(lines, {d, row_y}, fn line, {d_acc, ly} ->
            d_acc = render_value_line(d_acc, line, ly, ctx)
            {d_acc, ly - line_height}
          end)

        next_y = current_y - line_height * max(length(lines), 1)
        {d, next_y}
      end)

    doc
  end

  @doc """
  Calculate the total height this key-value list will occupy,
  accounting for word-wrap on long values.

  Takes the same `style` map as `render/4` plus the `pairs` list.
  Returns the height in points.
  """
  def measure_height(style \\ %{}, pairs) do
    font = Map.get(style, :font, @default_font)
    font_size = Map.get(style, :font_size, @default_font_size)
    line_height = Map.get(style, :line_height, @default_line_height)
    width = Map.get(style, :width, 300)
    label_w = trunc(width * Map.get(style, :label_width, @default_label_width))
    value_bold = Map.get(style, :value_bold, false)

    font_struct = Pdf.Fonts.get_internal_font(font, if(value_bold, do: [bold: true], else: []))
    vf = font_struct || Pdf.Fonts.get_internal_font(font)
    value_w = width - label_w

    Enum.reduce(pairs, 0, fn {_label, value}, total ->
      lines = wrap_value(value, vf, font_size, value_w)
      total + line_height * max(length(lines), 1)
    end)
  end

  # ── Value line rendering ─────────────────────────────────────────

  # Plain string line
  defp render_value_line(doc, text, ly, ctx) when is_binary(text) do
    lx =
      case ctx.value_align do
        :right ->
          tw = if ctx.vf, do: Pdf.Font.text_width(ctx.vf, text, ctx.font_size), else: 0
          ctx.x + ctx.width - tw
        _ ->
          ctx.x + ctx.label_w
      end

    doc
    |> Pdf.set_font(ctx.font, ctx.font_size, bold: ctx.value_bold)
    |> Pdf.set_fill_color(ctx.value_color)
    |> Pdf.text_at({lx, ly}, text)
  end

  # Rich text line — list of %{text, color} segments
  defp render_value_line(doc, segments, ly, ctx) when is_list(segments) do
    case ctx.value_align do
      :right ->
        # Measure total line width, then render from right edge
        total_w =
          Enum.reduce(segments, 0, fn seg, acc ->
            tw = if ctx.vf, do: Pdf.Font.text_width(ctx.vf, seg.text, ctx.font_size), else: 0
            acc + tw
          end)

        start_x = ctx.x + ctx.width - total_w

        Enum.reduce(segments, {doc, start_x}, fn seg, {d, sx} ->
          color = Map.get(seg, :color, ctx.value_color)
          tw = if ctx.vf, do: Pdf.Font.text_width(ctx.vf, seg.text, ctx.font_size), else: 0

          d =
            d
            |> Pdf.set_font(ctx.font, ctx.font_size, bold: ctx.value_bold)
            |> Pdf.set_fill_color(color)
            |> Pdf.text_at({sx, ly}, seg.text)

          {d, sx + tw}
        end)
        |> elem(0)

      _ ->
        Enum.reduce(segments, {doc, ctx.x + ctx.label_w}, fn seg, {d, sx} ->
          color = Map.get(seg, :color, ctx.value_color)
          tw = if ctx.vf, do: Pdf.Font.text_width(ctx.vf, seg.text, ctx.font_size), else: 0

          d =
            d
            |> Pdf.set_font(ctx.font, ctx.font_size, bold: ctx.value_bold)
            |> Pdf.set_fill_color(color)
            |> Pdf.text_at({sx, ly}, seg.text)

          {d, sx + tw}
        end)
        |> elem(0)
    end
  end

  # ── Wrap dispatcher ──────────────────────────────────────────────

  # Plain string → list of strings
  defp wrap_value(text, font_struct, font_size, max_width) when is_binary(text) do
    wrap_plain_text(text, font_struct, font_size, max_width)
  end

  # Rich text → list of [%{text, color}, ...] per line
  defp wrap_value(spans, font_struct, font_size, max_width) when is_list(spans) do
    spans
    |> flatten_to_colored_words()
    |> wrap_colored_words(font_struct, font_size, max_width)
  end

  # ── Plain text wrap ──────────────────────────────────────────────

  defp wrap_plain_text(text, font_struct, font_size, max_width) do
    words = String.split(text)

    {lines, current_line} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        w =
          if font_struct,
            do: Pdf.Font.text_width(font_struct, candidate, font_size),
            else: String.length(candidate) * font_size * 0.5

        if w > max_width and current != "" do
          {lines ++ [current], word}
        else
          {lines, candidate}
        end
      end)

    if current_line != "", do: lines ++ [current_line], else: lines
  end

  # ── Rich text wrap ───────────────────────────────────────────────

  defp flatten_to_colored_words(spans) do
    Enum.flat_map(spans, fn span ->
      color = Map.get(span, :color)
      span.text
      |> String.split()
      |> Enum.map(&{&1, color})
    end)
  end

  defp wrap_colored_words(words, font_struct, font_size, max_width) do
    {lines, current_words, _current_text} =
      Enum.reduce(words, {[], [], ""}, fn {word, color}, {lines, cw, ct} ->
        candidate = if ct == "", do: word, else: ct <> " " <> word

        w =
          if font_struct,
            do: Pdf.Font.text_width(font_struct, candidate, font_size),
            else: String.length(candidate) * font_size * 0.5

        if w > max_width and ct != "" do
          {lines ++ [collapse_colored_words(cw)], [{word, color}], word}
        else
          {lines, cw ++ [{word, color}], candidate}
        end
      end)

    if current_words != [],
      do: lines ++ [collapse_colored_words(current_words)],
      else: lines
  end

  defp collapse_colored_words(words) do
    words
    |> Enum.reduce([], fn {word, color}, acc ->
      case acc do
        [%{text: text, color: ^color} | rest] ->
          [%{text: text <> " " <> word, color: color} | rest]
        _ ->
          [%{text: word, color: color} | acc]
      end
    end)
    |> Enum.reverse()
  end
end
