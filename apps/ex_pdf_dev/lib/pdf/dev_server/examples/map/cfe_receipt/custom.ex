defmodule Pdf.DevServer.Examples.Map.CfeReceipt.Custom do
  @moduledoc false

  @green {0.0, 0.518, 0.239}
  @green_hdr {0.0, 0.44, 0.22}
  @green_dark {0.0, 0.32, 0.16}
  @green_row {0.0, 0.50, 0.28}
  @black {0.0, 0.0, 0.0}
  @gray {0.28, 0.28, 0.28}
  @gray_mid {0.50, 0.50, 0.50}
  @line {0.70, 0.70, 0.70}
  @line_faint {0.84, 0.84, 0.84}
  @bg_total {0.88, 0.88, 0.88}
  @white {1.0, 1.0, 1.0}

  def period_bar(doc, text) do
    %{x: x, y: y} = Pdf.cursor_xy(doc)
    h = 9

    doc =
      doc
      |> fill_rect(x, y, content_w(doc), h, @green_hdr)
      |> text_at(x + 3, y - 2, text, font_size: 6.2, bold: true, color: @white)

    Pdf.set_cursor(doc, y - h)
    doc
  end

  def consumption_table(doc, data) do
    area = Pdf.content_area(doc)
    x = area.x
    w = area.width
    y = area.y

    cols = scale_cols([76, 35, 29, 35, 29, 41, 43, 52], w)
    xs = col_starts(x, cols)
    h1 = 11
    h2 = 9
    rh = 9.5
    table_h = h1 + h2 + length(data.consumption_body) * rh

    doc =
      doc
      |> merged_header_rounded(y - h1, xs, cols, h1, [
        {0, 1, "Concepto"},
        {1, 2, "Lectura actual"},
        {3, 2, "Lectura anterior"},
        {5, 1, "Total\nperiodo"},
        {6, 1, "Precio\n(MXN)"},
        {7, 1, "Subtotal\n(MXN)"}
      ])
      |> sub_header(y - h1 - h2, xs, cols, h2, [
        {1, "Medida"},
        {2, "Estimada"},
        {3, "Medida"},
        {4, "Estimada"}
      ])

    doc =
      Enum.with_index(data.consumption_body)
      |> Enum.reduce({doc, y - h1 - h2}, fn {row, idx}, {d, ry} ->
        y2 = ry - rh
        bold = row_bold?(row)

        {bg, fg} =
          cond do
            idx == 0 -> {@green_row, @white}
            bold -> {@bg_total, @black}
            rem(idx, 2) == 0 -> {@white, @black}
            true -> {{0.975, 0.975, 0.975}, @black}
          end

        d =
          d
          |> fill_row(y2, xs, cols, rh, bg)
          |> grid_row(y2, xs, cols, rh)
          |> then(fn dd ->
            Enum.with_index(row)
            |> Enum.reduce(dd, fn {cell, ci}, acc ->
              align = if ci >= 5, do: :right, else: :left
              pad = 2

              text_cell(
                acc,
                Enum.at(xs, ci) + pad,
                ry - 6,
                Enum.at(cols, ci) - pad * 2,
                cell,
                bold: bold or idx == 0,
                align: align,
                size: 6,
                color: fg
              )
            end)
          end)

        {d, y2}
      end)
      |> elem(0)

    Pdf.set_cursor(doc, y - table_h)
    doc
  end

  def consumption_gauge(doc, data) do
    area = Pdf.content_area(doc)
    x = area.x
    y = area.y
    w = area.width
    pct = data.consumption_percent
    bar_x = x + 28
    bar_w = w - 32
    h = 5

    doc =
      doc
      |> draw_house(x, y)
      |> draw_gradient_bar(bar_x, y, bar_w, h, pct)
      |> text_at(bar_x, y - h - 8, data.gauge_label, font_size: 5.2, color: @gray_mid)

    Pdf.set_cursor(doc, y - h - 14)
    doc
  end

  def promo_mascot(doc, x, y) do
    skin = {0.96, 0.84, 0.70}

    doc
    |> fill_rect(x + 8, y - 7, 9, 9, skin)
    |> fill_rect(x + 5, y - 20, 15, 13, @green)
    |> fill_rect(x + 2, y - 32, 7, 12, @green)
    |> fill_rect(x + 16, y - 32, 7, 12, @green)
    |> fill_rect(x + 6, y - 34, 13, 3, skin)
    |> fill_rect(x + 4, y - 36, 17, 2, @green_dark)
  end

  def id_bar(doc, text) do
    %{x: x, y: y} = Pdf.cursor_xy(doc)
    h = 10
    w = content_w(doc)

    doc =
      doc
      |> fill_rect(x, y, w, h, @green_hdr)
      |> text_center(x, y - 3, w, text, size: 6, bold: true, color: @white)

    Pdf.set_cursor(doc, y - h)
    doc
  end

  def payment_strip(doc, data) do
    area = Pdf.content_area(doc)
    x = area.x
    y = area.y
    w = area.width
    h = 54

    doc =
      doc
      |> hline(x, y, x + w, @line)
      |> hline(x, y - h, x + w, @line)

    doc =
      Pdf.Component.QrCode.render(doc, {x + 5, y - 5}, %{
        data: data.qr_payload,
        size: 40,
        ec_level: :m,
        padding: 1,
        background: @white,
        color: @black
      })

    doc =
      doc
      |> text_at(x + w / 2, y - 8, data.barcode_top, font_size: 5, align: :center, box_w: 190)

    doc =
      Pdf.Component.Barcode.render(doc, {x + w / 2 - 92, y - 34}, %{
        data: data.barcode_data,
        width: 184,
        height: 24,
        show_text: false
      })

    doc
    |> text_at(x + w / 2, y - h + 7, data.barcode_bottom, font_size: 5, align: :center, box_w: 190)
    |> text_at(x + w - 6, y - 12, "TOTAL A PAGAR", font_size: 6.2, bold: true, align: :right, box_w: 105)
    |> text_at(x + w - 6, y - 27, data.total_display, font_size: 19, bold: true, align: :right, box_w: 105)
    |> text_at(x + w - 6, y - 38, "(#{data.total_words})", font_size: 4.3, color: @gray, align: :right, box_w: 105)
    |> then(fn d -> Pdf.set_cursor(d, y - h); d end)
  end

  # ── internals ────────────────────────────────────────────────────────────────

  defp content_w(doc) do
    area = Pdf.content_area(doc)
    area.width
  end

  defp draw_house(doc, x, y) do
    doc
    |> fill_rect(x + 5, y - 7, 12, 8, {0.88, 0.94, 0.90})
    |> fill_rect(x + 3, y - 1, 16, 1.5, @green)
    |> fill_rect(x + 9, y - 5, 3, 3, @white)
  end

  defp draw_gradient_bar(doc, x, y, w, h, pct) do
    n = 55
    seg = w / n

    colors = [
      {0.10, 0.52, 0.24},
      {0.55, 0.78, 0.15},
      {0.92, 0.82, 0.08},
      {0.95, 0.48, 0.06},
      {0.76, 0.08, 0.08}
    ]

    doc =
      Enum.reduce(0..(n - 1), doc, fn i, d ->
        t = i / max(n - 1, 1)
        fill_rect(d, x + i * seg, y - h, seg + 0.15, h, lerp_colors(colors, t))
      end)

    mx = x + w * pct / 100

    doc
    |> fill_rect(mx - 0.8, y - h - 2, 1.6, h + 4, @black)
    |> stroke_rect(x, y - h, w, h, 0.25, @line)
  end

  defp merged_header_rounded(doc, y, xs, cols, h, groups) do
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

  defp sub_header(doc, y, xs, cols, h, cells) do
    doc = fill_row(doc, y, xs, cols, h, @green)

    Enum.reduce(cells, doc, fn {ci, text}, d ->
      cx = Enum.at(xs, ci)
      cw = Enum.at(cols, ci)

      d
      |> vline(cx, y, y - h, @green_dark)
      |> text_center(cx, y + h - 6, cw, text, size: 5.4, bold: true, color: @white)
    end)
  end

  defp grid_row(doc, y, xs, cols, h) do
    doc
    |> hline(hd(xs), y, hd(xs) + Enum.sum(cols), @line_faint)
    |> hline(hd(xs), y - h, hd(xs) + Enum.sum(cols), @line_faint)
    |> then(fn d ->
      Enum.reduce(xs, d, fn cx, acc -> vline(acc, cx, y, y - h, @line_faint) end)
    end)
    |> vline(hd(xs) + Enum.sum(cols), y, y - h, @line_faint)
  end

  defp text_at(doc, x, y, text, opts) do
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

  defp text_center(doc, x, y, w, text, opts) do
    fs = Keyword.get(opts, :size, 6.5)
    bold = Keyword.get(opts, :bold, true)
    color = Keyword.get(opts, :color, @white)

    doc = Pdf.set_font(doc, "Helvetica", fs, bold: bold)
    mod = doc.current.current_font.module
    tw = Pdf.Font.text_width(mod, text, fs)
    doc |> Pdf.set_fill_color(color) |> Pdf.text_at({x + max((w - tw) / 2, 0), y}, text)
  end

  defp text_cell(doc, x, y, w, text, opts) do
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

  defp fill_rect(doc, x, y, w, h, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(color)
    |> Pdf.rectangle({x, y - h}, {w, h})
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  defp fill_rounded_rect(doc, x, y, w, h, r, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(color)
    |> Pdf.rounded_rectangle({x, y - h}, {w, h}, r)
    |> Pdf.fill()
    |> Pdf.restore_state()
  end

  defp stroke_rect(doc, x, y, w, h, lw, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(lw)
    |> Pdf.rectangle({x, y - h}, {w, h})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  defp hline(doc, x1, y, x2, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(0.35)
    |> Pdf.line({x1, y}, {x2, y})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  defp vline(doc, x, y1, y2, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(0.35)
    |> Pdf.line({x, y1}, {x, y2})
    |> Pdf.stroke()
    |> Pdf.restore_state()
  end

  defp fill_row(doc, y, xs, cols, h, color), do: fill_rect(doc, hd(xs), y, Enum.sum(cols), h, color)

  defp col_starts(x, cols) do
    {starts, _} = Enum.reduce(cols, {[x], x}, fn cw, {acc, cur} -> {acc ++ [cur + cw], cur + cw} end)
    Enum.drop(starts, -1)
  end

  defp scale_cols(cols, target) do
    total = Enum.sum(cols)
    cols |> Enum.map(fn c -> round(c / total * target) end) |> adjust_cols(trunc(target))
  end

  defp adjust_cols(cols, target) do
    diff = target - Enum.sum(cols)
    if diff == 0, do: cols, else: List.update_at(cols, -1, &(&1 + diff))
  end

  defp row_bold?(row) do
    f = to_string(hd(row) || "")
    String.contains?(f, "Suma")
  end

  defp lerp_colors(colors, t) do
    idx = min(trunc(t * (length(colors) - 1)), length(colors) - 2)
    f = t * (length(colors) - 1) - idx
    {r1, g1, b1} = Enum.at(colors, idx)
    {r2, g2, b2} = Enum.at(colors, idx + 1)
    {r1 + (r2 - r1) * f, g1 + (g2 - g1) * f, b1 + (b2 - b1) * f}
  end
end
