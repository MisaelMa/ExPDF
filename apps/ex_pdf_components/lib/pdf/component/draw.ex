defmodule Pdf.Component.Draw do
  @moduledoc false

  @green {0.0, 0.518, 0.239}
  @green_hdr {0.0, 0.44, 0.22}
  @green_dark {0.0, 0.32, 0.16}
  @green_row {0.0, 0.50, 0.28}
  @black {0.0, 0.0, 0.0}
  @gray {0.28, 0.28, 0.28}
  @gray_mid {0.50, 0.50, 0.50}
  @gray_light {0.92, 0.92, 0.92}
  @line {0.70, 0.70, 0.70}
  @line_faint {0.84, 0.84, 0.84}
  @bg_total {0.88, 0.88, 0.88}
  @white {1.0, 1.0, 1.0}

  def green, do: @green
  def green_hdr, do: @green_hdr
  def green_dark, do: @green_dark
  def green_row, do: @green_row
  def black, do: @black
  def gray, do: @gray
  def gray_mid, do: @gray_mid
  def gray_light, do: @gray_light
  def line, do: @line
  def line_faint, do: @line_faint
  def bg_total, do: @bg_total
  def white, do: @white

  def text_at(doc, x, y, text, opts) do
    fs = Keyword.get(opts, :font_size, 7)
    bold = Keyword.get(opts, :bold, false)
    color = Keyword.get(opts, :color, @black)
    align = Keyword.get(opts, :align, :left)
    box_w = Keyword.get(opts, :box_w, 0)

    doc = Pdf.set_font(doc, "Helvetica", fs, bold: bold)
    mod = doc.current.current_font.module
    tw = Pdf.Font.text_width(mod, text, fs)

    tx =
      case align do
        :right when box_w > 0 -> x - tw
        :center when box_w > 0 -> x + (box_w - tw) / 2
        _ -> x
      end

    doc |> Pdf.set_fill_color(color) |> Pdf.text_at({tx, y}, text)
  end

  def text_center(doc, x, y, w, text, opts) do
    fs = Keyword.get(opts, :size, 6.5)
    bold = Keyword.get(opts, :bold, true)
    color = Keyword.get(opts, :color, @white)

    String.split(text, "\n")
    |> Enum.with_index()
    |> Enum.reduce(doc, fn {line, i}, d ->
      d = Pdf.set_font(d, "Helvetica", fs, bold: bold)
      mod = d.current.current_font.module
      tw = Pdf.Font.text_width(mod, line, fs)
      d |> Pdf.set_fill_color(color) |> Pdf.text_at({x + max((w - tw) / 2, 0), y - i * (fs + 0.8)}, line)
    end)
  end

  def text_cell(doc, x, y, w, text, opts) do
    fs = Keyword.get(opts, :size, 6.5)
    bold = Keyword.get(opts, :bold, false)
    align = Keyword.get(opts, :align, :left)
    color = Keyword.get(opts, :color, @black)

    doc = Pdf.set_font(doc, "Helvetica", fs, bold: bold)
    mod = doc.current.current_font.module
    tw = Pdf.Font.text_width(mod, text, fs)

    tx =
      case align do
        :right -> x + max(w - tw, 0)
        :center -> x + max((w - tw) / 2, 0)
        _ -> x
      end

    doc |> Pdf.set_fill_color(color) |> Pdf.text_at({tx, y}, text)
  end

  def fill_rect(doc, x, y, w, h, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(color)
    |> Pdf.rectangle({x, y - h}, {w, h})
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  def fill_rounded_rect(doc, x, y, w, h, r, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(color)
    |> Pdf.rounded_rectangle({x, y - h}, {w, h}, r)
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  def stroke_rect(doc, x, y, w, h, lw, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(lw)
    |> Pdf.rectangle({x, y - h}, {w, h})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  def stroke_rounded_rect(doc, x, y, w, h, r, lw, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(lw)
    |> Pdf.rounded_rectangle({x, y - h}, {w, h}, r)
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  def hline(doc, x1, y, x2, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(0.35)
    |> Pdf.line({x1, y}, {x2, y})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  def vline(doc, x, y1, y2, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(0.35)
    |> Pdf.line({x, y1}, {x, y2})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  def fill_row(doc, y, xs, cols, h, color), do: fill_rect(doc, hd(xs), y, Enum.sum(cols), h, color)

  def col_starts(x, cols) do
    {starts, _} = Enum.reduce(cols, {[x], x}, fn cw, {acc, cur} -> {acc ++ [cur + cw], cur + cw} end)
    Enum.drop(starts, -1)
  end

  def scale_cols(cols, target) do
    total = Enum.sum(cols)
    cols |> Enum.map(fn c -> round(c / total * target) end) |> adjust_cols(trunc(target))
  end

  defp adjust_cols(cols, target) do
    diff = target - Enum.sum(cols)
    if diff == 0, do: cols, else: List.update_at(cols, -1, &(&1 + diff))
  end

  def row_bold?(row) do
    f = to_string(hd(row) || "")
    String.contains?(f, "Suma")
  end

  def lerp_colors(colors, t) do
    idx = min(trunc(t * (length(colors) - 1)), length(colors) - 2)
    f = t * (length(colors) - 1) - idx
    {r1, g1, b1} = Enum.at(colors, idx)
    {r2, g2, b2} = Enum.at(colors, idx + 1)
    {r1 + (r2 - r1) * f, g1 + (g2 - g1) * f, b1 + (b2 - b1) * f}
  end

  def merged_header_rounded(doc, y, xs, cols, h, groups) do
    x0 = hd(xs)
    tw = Enum.sum(cols)

    doc = fill_rounded_rect(doc, x0, y, tw, h, 2.5, @green_hdr)

    Enum.reduce(groups, doc, fn {start, span, text}, d ->
      cx = Enum.at(xs, start)
      cw = Enum.slice(cols, start, span) |> Enum.sum()

      d
      |> vline(cx, y, y - h, @green_dark)
      |> text_center(cx, y + h - 7, cw, text, size: 5.8, bold: true, color: @white)
    end)
    |> vline(x0 + tw, y, y - h, @green_dark)
  end

  def merged_header(doc, y, xs, cols, h, groups) do
    doc = fill_row(doc, y, xs, cols, h, @green_hdr)

    Enum.reduce(groups, doc, fn {start, span, text}, d ->
      cx = Enum.at(xs, start)
      cw = Enum.slice(cols, start, span) |> Enum.sum()

      d
      |> vline(cx, y, y - h, @green_dark)
      |> text_center(cx, y + h - 7, cw, text, size: 5.8, bold: true, color: @white)
    end)
    |> vline(Enum.at(xs, 0) + Enum.sum(cols), y, y - h, @green_dark)
  end

  def sub_header(doc, y, xs, cols, h, cells) do
    doc = fill_row(doc, y, xs, cols, h, @green)

    Enum.reduce(cells, doc, fn {ci, text}, d ->
      cx = Enum.at(xs, ci)
      cw = Enum.at(cols, ci)

      d
      |> vline(cx, y, y - h, @green_dark)
      |> text_center(cx, y + h - 6, cw, text, size: 5.4, bold: true, color: @white)
    end)
  end

  def grid_row(doc, y, xs, cols, h) do
    doc
    |> hline(hd(xs), y, hd(xs) + Enum.sum(cols), @line_faint)
    |> hline(hd(xs), y - h, hd(xs) + Enum.sum(cols), @line_faint)
    |> then(fn d ->
      Enum.reduce(xs, d, fn cx, acc -> vline(acc, cx, y, y - h, @line_faint) end)
    end)
    |> vline(hd(xs) + Enum.sum(cols), y, y - h, @line_faint)
  end
end
