defmodule Pdf.DevServer.Examples.Map.CfeReceipt.Layout do
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

  @margin 8
  @page_h 842
  @page_w 595
  @content_w @page_w - @margin * 2

  @footer_id_h 10
  @footer_pay_h 54
  @footer_contact_h 10

  def render(doc, data) do
    x = @margin
    w = @content_w
    top = @page_h - @margin

    doc = draw_header(doc, x, top, w, data)

    {doc, y} = draw_upper_block(doc, x, top - 38, w, data)
    y = y - 4
    {doc, y} = draw_period_bar(doc, x, y, w, data)
    y = y - 2
    {doc, y} = draw_consumption_table(doc, x, y, w, data)
    y = y - 5
    doc = draw_consumption_gauge(doc, x, y, w, data)
    y = y - 18
    {doc, y} = draw_cost_tables(doc, x, y, w, data)
    y = y - 6
    doc = draw_footnotes(doc, x, y, w)
    y = y - 12
    doc = draw_print_line(doc, x, y, data)

    draw_footer(doc, x, w, data, y - 8)
  end

  # ── Header ───────────────────────────────────────────────────────────────────

  defp draw_header(doc, x, y, w, data) do
    logo = logo_path()

    doc =
      if File.exists?(logo) do
        Pdf.add_image(doc, {x, y - 28}, logo, width: 118, height: 43)
      else
        draw_logo_fallback(doc, x, y)
      end

    tx = x + w - 178

    doc
    |> text_at(tx, y - 6, data.rfc_line, font_size: 5, color: @gray_mid, align: :right, box_w: 175)
    |> text_at(tx, y - 12, data.company_line, font_size: 5, color: @gray_mid, align: :right, box_w: 175)
    |> text_at(tx, y - 18, data.company_line2, font_size: 5, color: @gray_mid, align: :right, box_w: 175)
  end

  defp logo_path do
    Application.app_dir(:ex_pdf_dev) |> Path.join("priv/pdf_assets/img/cfe_logo.png")
  end

  defp draw_logo_fallback(doc, x, y) do
    doc
    |> text_at(x, y - 16, "CFE", font_size: 20, bold: true, color: @green)
    |> text_at(x + 36, y - 8, "Comisión Federal de Electricidad®", font_size: 6, bold: true, color: @green)
  end

  # ── Bloque superior 58 / 42 (sin marco verde — como referencia MEZETA) ───────

  defp draw_upper_block(doc, x, y, w, data) do
    h = 120
    split = x + trunc(w * 0.58)
    left_w = split - x - 2
    right_x = split + 4
    right_w = x + w - right_x

    doc =
      doc
      |> stroke_rect(x, y, w, h, 0.45, @line)
      |> vline(split, y, y - h, @line_faint)
      |> then(&draw_customer_block(&1, x, y, left_w, h, data))
      |> then(&draw_total_block(&1, right_x, y, right_w, h, data))

    {doc, y - h}
  end

  defp draw_customer_block(doc, x, y, w, _h, data) do
    doc
    |> text_at(x + 2, y - 11, data.customer_name, font_size: 9, bold: true, color: @black)
    |> text_at(x + 2, y - 20, data.customer_address1, font_size: 6.3, color: @black)
    |> text_at(x + 2, y - 28, data.customer_address2, font_size: 6.3, color: @black)
    |> text_at(x + 2, y - 36, data.customer_address3, font_size: 6.3, color: @black)
    |> text_at(x + 2, y - 47, "NO. DE SERVICIO : #{data.service_number}", font_size: 6.5, bold: true, color: @black)
    |> text_at(x + 2, y - 55, "RMU : #{data.rmu}", font_size: 6.3, bold: true, color: @black)
    |> draw_field_grid(x + 2, y - 66, w - 4, data.service_stack)
  end

  defp draw_field_grid(doc, x, y, w, fields) do
    col_w = div(trunc(w), 2)
    row_h = 10.5
    val_w = 52

    Enum.with_index(fields)
    |> Enum.reduce(doc, fn {{label, value}, idx}, d ->
      row = div(idx, 2)
      col = rem(idx, 2)
      cx = x + col * col_w
      cy = y - row * row_h
      limit? = label == "LÍMITE DE PAGO:"

      d
      |> text_at(cx, cy, label, font_size: 5.8, bold: true, color: @black)
      |> text_at(cx + 62, cy, value, font_size: 5.8, bold: limit?, color: @black)
      |> then(fn dd -> hline(dd, cx + 62, cy - 2.2, cx + 62 + val_w, @line_faint) end)
    end)
  end

  defp draw_total_block(doc, x, y, w, panel_h, data) do
    total_h = 36

    doc =
      doc
      |> fill_rect(x, y - total_h, w, total_h, @bg_total)
      |> stroke_rect(x, y - total_h, w, total_h, 0.35, @line)
      |> text_at(x + w - 5, y - 9, "TOTAL A PAGAR:", font_size: 7, bold: true, align: :right, box_w: w - 8)
      |> text_at(x + w - 5, y - 26, data.total_display, font_size: 22, bold: true, align: :right, box_w: w - 8)
      |> text_at(x + w - 5, y - 33, "(#{data.total_words})", font_size: 4.8, color: @gray, align: :right, box_w: w - 8)

    promo_h = panel_h - total_h - 3
    draw_promo_box(doc, x, y - total_h - 3, w, promo_h, data)
  end

  defp draw_promo_box(doc, x, y_top, w, h, data) do
    pad = 4
    qr = min(trunc(h - 8), 50)

    doc =
      doc
      |> fill_rounded_rect(x, y_top, w, h, 3, @gray_light)
      |> stroke_rounded_rect(x, y_top, w, h, 3, 0.4, @line)

    doc =
      doc
      |> draw_technician(x + pad, y_top - pad - 2)
      |> text_at(x + pad + 38, y_top - 10, "Obtén tu aviso recibo", font_size: 5.5, bold: true, color: @black)
      |> text_at(x + pad + 38, y_top - 17, "más fácil y rápido", font_size: 5.5, bold: true, color: @black)
      |> text_at(x + pad + 38, y_top - 25, "Actualiza tus datos", font_size: 5, color: @gray_mid)
      |> text_at(x + pad + 38, y_top - 31, "mediante el QR...", font_size: 5, color: @gray_mid)
      |> text_at(x + pad + 38, y_top - h + 9, "¡Escanea el código y listo!", font_size: 5.2, bold: true, color: @green)

    qr_x = x + w - qr - pad

    Pdf.Component.QrCode.render(doc, {qr_x, y_top - pad}, %{
      data: data.qr_payload,
      size: qr,
      ec_level: :m,
      padding: 1,
      background: @white,
      color: @black
    })
  end

  defp draw_technician(doc, x, y) do
    skin = {0.96, 0.84, 0.70}
    scale = 0.72
    ox = x + 6
    oy = y - 2

    doc
    |> fill_rect(ox + 8 * scale, oy - 7 * scale, 9 * scale, 9 * scale, skin)
    |> fill_rect(ox + 5 * scale, oy - 20 * scale, 15 * scale, 13 * scale, @green)
    |> fill_rect(ox + 2 * scale, oy - 30 * scale, 7 * scale, 10 * scale, @green)
    |> fill_rect(ox + 16 * scale, oy - 30 * scale, 7 * scale, 10 * scale, @green)
    |> fill_rect(ox + 6 * scale, oy - 32 * scale, 13 * scale, 3 * scale, skin)
    |> fill_rect(ox + 4 * scale, oy - 34 * scale, 17 * scale, 2 * scale, @green_dark)
  end

  # ── Periodo ──────────────────────────────────────────────────────────────────

  defp draw_period_bar(doc, x, y, w, data) do
    text = "PERIODO FACTURADO: #{data.billing_period}"

    doc =
      doc
      |> fill_rect(x, y - 9, w, 9, @green_hdr)
      |> text_center(x, y - 2, w, text, size: 6.2, bold: true, color: @white)

    {doc, y - 9}
  end

  # ── Tabla consumo ────────────────────────────────────────────────────────────

  defp draw_consumption_table(doc, x, y, w, data) do
    cols = scale_cols([76, 35, 29, 35, 29, 41, 43, 52], w)
    xs = col_starts(x, cols)
    h1 = 11
    h2 = 9
    rh = 9.5
    rows = length(data.consumption_body)
    table_h = h1 + h2 + rows * rh

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
          |> then(fn dd ->
            if bold do
              hline(dd, hd(xs), ry, hd(xs) + Enum.sum(cols), @line)
            else
              dd
            end
          end)
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
      |> stroke_rounded_rect(hd(xs), y, Enum.sum(cols), table_h, 2.5, 0.35, @line)

    {doc, y - table_h}
  end

  defp draw_consumption_gauge(doc, x, y, w, data) do
    pct = data.consumption_percent
    bar_x = x + 28
    bar_w = w - 32
    h = 5

    doc
    |> draw_house(x, y)
    |> draw_gradient_bar(bar_x, y, bar_w, h, pct)
    |> text_at(bar_x, y - h - 8, data.gauge_label, font_size: 5.2, color: @gray_mid)
  end

  defp draw_house(doc, x, y) do
    doc
    |> fill_rect(x + 5, y - 7, 12, 8, @gray_light)
    |> fill_rect(x + 3, y - 1, 16, 1.5, @green)
    |> fill_rect(x + 9, y - 5, 3, 3, @white)
  end

  defp draw_gradient_bar(doc, x, y, w, h, pct) do
    n = 55
    seg = w / n

    colors = [
      {0.10, 0.52, 0.24},
      {0.52, 0.76, 0.14},
      {0.90, 0.80, 0.08},
      {0.94, 0.46, 0.06},
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

  # ── Tablas costos ────────────────────────────────────────────────────────────

  defp draw_cost_tables(doc, x, y, w, data) do
    gap = 6
    left_w = trunc((w - gap) * 0.54)
    right_w = w - gap - left_w
    lx = x
    rx = x + left_w + gap

    doc =
      doc
      |> section_band(lx, y, left_w, "Costos de la energía en el Mercado Eléctrico Mayorista")
      |> section_band(rx, y, right_w, "Desglose del importe a pagar")

    top = y - 10
    lh = 10 + length(data.costs) * 8.5
    rh = 10 + length(data.breakdown) * 8.5
    sh = max(lh, rh)

    doc
    |> stroke_rect(lx, top - sh, left_w, sh, 0.4, @line)
    |> draw_mem_table(lx, top, left_w, data.costs)
    |> stroke_rect(rx, top - sh, right_w, sh, 0.4, @line)
    |> draw_breakdown_table(rx, top, right_w, data.breakdown)
    |> then(fn d -> {d, top - sh} end)
  end

  defp draw_mem_table(doc, x, y, w, rows) do
    cols = scale_cols([66, 32, 32, 32, 44], w)
    xs = col_starts(x, cols)
    hh = 10
    rh = 8.5

    doc =
      merged_header(doc, y - hh, xs, cols, hh, [
        {0, 1, "Concepto"},
        {1, 1, "$"},
        {2, 1, "$/kW"},
        {3, 1, "$/kWh"},
        {4, 1, "Importe\n(MXN)"}
      ])

    Enum.with_index(rows)
    |> Enum.reduce({doc, y - hh}, fn {row, idx}, {d, ry} ->
      y2 = ry - rh
      bg = if rem(idx, 2) == 0, do: @white, else: {0.975, 0.975, 0.975}

      d =
        d
        |> fill_row(y2, xs, cols, rh, bg)
        |> grid_row(y2, xs, cols, rh)
        |> then(fn dd ->
          Enum.with_index(row)
          |> Enum.reduce(dd, fn {cell, ci}, acc ->
            align = if ci == 0, do: :left, else: :right
            text_cell(acc, Enum.at(xs, ci) + 2, ry - 5.5, Enum.at(cols, ci) - 4, cell, align: align, size: 5.9)
          end)
        end)

      {d, y2}
    end)
    |> elem(0)
  end

  defp draw_breakdown_table(doc, x, y, w, rows) do
    cols = scale_cols([108, 56], w)
    xs = col_starts(x, cols)
    hh = 10
    rh = 8.5

    doc =
      merged_header(doc, y - hh, xs, cols, hh, [
        {0, 1, "Concepto"},
        {1, 1, "Importe (MXN)"}
      ])

    Enum.with_index(rows)
    |> Enum.reduce({doc, y - hh}, fn {{label, value}, idx}, {d, ry} ->
      y2 = ry - rh
      bold = label == "Total"
      bg = if bold, do: @bg_total, else: if(rem(idx, 2) == 0, do: @white, else: {0.975, 0.975, 0.975})

      d
      |> fill_row(y2, xs, cols, rh, bg)
      |> grid_row(y2, xs, cols, rh)
      |> text_cell(Enum.at(xs, 0) + 2, ry - 5.5, Enum.at(cols, 0) - 4, label, bold: bold, size: 5.9)
      |> text_cell(Enum.at(xs, 1) + 2, ry - 5.5, Enum.at(cols, 1) - 4, value, bold: bold, align: :right, size: 5.9)
      |> then(fn dd -> {dd, y2} end)
    end)
    |> elem(0)
  end

  # ── Notas ────────────────────────────────────────────────────────────────────

  defp draw_footnotes(doc, x, y, w) do
    doc
    |> text_at(x, y, "* SCnMEM: Servicios Conexos no Membreses.", font_size: 4.8, color: @gray_mid)
    |> text_at(x, y - 6, "* DAP: Derecho al Alumbrado Público.", font_size: 4.8, color: @gray_mid)
    |> text_at(x + w * 0.52, y, "Los importes incluyen IVA cuando aplique.", font_size: 4.8, color: @gray_mid)
  end

  defp draw_print_line(doc, x, y, data) do
    text_at(doc, x, y, data.print_info, font_size: 4.6, color: @gray_mid)
  end

  # ── Pie en flujo (justo debajo del contenido, como referencia MEZETA) ────────

  defp draw_footer(doc, x, w, data, start_y) do
    id_y = start_y

    doc =
      doc
      |> dash_hline(x, id_y + 2, x + w, @line)

    payment_y = id_y - @footer_id_h
    contact_y = payment_y - @footer_pay_h

    doc
    |> draw_id_bar(x, id_y, w, data)
    |> draw_payment_strip(x, payment_y, w, data)
    |> draw_contact_bar(x, contact_y, w)
  end

  defp draw_contact_bar(doc, x, y, w) do
    doc
    |> fill_rect(x, y - @footer_contact_h, w, @footer_contact_h, @green_hdr)
    |> text_at(x + 5, y - 2, "CFE-contigo", font_size: 6.2, bold: true, color: @white)
    |> text_at(x + 62, y - 2, "071", font_size: 6.8, bold: true, color: @white)
    |> text_at(x + 95, y - 2, "@CFEmx    cfe.mx    Facebook    Instagram", font_size: 5.2, color: @white)
  end

  defp draw_id_bar(doc, x, y, w, data) do
    doc
    |> fill_rect(x, y - @footer_id_h, w, @footer_id_h, @green_hdr)
    |> text_at(x + w / 2, y - 3, data.barcode_top, font_size: 6, bold: true, color: @white, align: :center, box_w: w)
  end

  defp draw_payment_strip(doc, x, y, w, data) do
    h = @footer_pay_h

    doc =
      doc
      |> hline(x, y, x + w, @line)
      |> hline(x, y - h, x + w, @line)
      |> vline(x + 52, y, y - h, @line_faint)

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
    |> text_at(x + w / 2, y - h + 7, data.barcode_bottom, font_size: 5, color: @black, align: :center, box_w: 200)
    |> text_at(x + w - 6, y - 12, "TOTAL A PAGAR:", font_size: 6.2, bold: true, align: :right, box_w: 105)
    |> text_at(x + w - 6, y - 27, data.total_display, font_size: 19, bold: true, align: :right, box_w: 105)
    |> text_at(x + w - 6, y - 38, "(#{data.total_words})", font_size: 4.3, color: @gray, align: :right, box_w: 105)
  end

  # ── Tabla helpers ────────────────────────────────────────────────────────────

  defp section_band(doc, x, y, w, title) do
    fs = if String.length(title) > 42, do: 5.6, else: 6

    doc
    |> fill_rounded_rect(x, y, w, 10, 2, @green_hdr)
    |> text_at(x + 3, y - 2, title, font_size: fs, bold: true, color: @white)
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

  defp merged_header(doc, y, xs, cols, h, groups) do
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

  # ── Primitivas ─────────────────────────────────────────────────────────────

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

    String.split(text, "\n")
    |> Enum.with_index()
    |> Enum.reduce(doc, fn {line, i}, d ->
      d = Pdf.set_font(d, "Helvetica", fs, bold: bold)
      mod = d.current.current_font.module
      tw = Pdf.Font.text_width(mod, line, fs)
      d |> Pdf.set_fill_color(color) |> Pdf.text_at({x + max((w - tw) / 2, 0), y - i * (fs + 0.8)}, line)
    end)
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

  defp stroke_rounded_rect(doc, x, y, w, h, r, lw, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(color)
    |> Pdf.set_line_width(lw)
    |> Pdf.rounded_rectangle({x, y - h}, {w, h}, r)
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

  defp dash_hline(doc, x1, y, x2, color) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_dash([3, 2], 0)
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
