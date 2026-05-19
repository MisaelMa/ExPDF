defmodule Pdf.DevServer.Examples.Api.CfdiInvoice do
  @moduledoc false

  def render do
    # Colors
    dark = {0.2, 0.2, 0.2}
    orange = {0.9, 0.55, 0.0}
    header_bg = {0.95, 0.95, 0.95}
    border_c = {0.4, 0.4, 0.4}
    light_border = {0.7, 0.7, 0.7}

    # Page setup
    doc = Pdf.new(size: :a4, margin: %{top: 30, bottom: 30, left: 30, right: 30})
    |> Pdf.set_info(title: "Factura CFDI")

    page_w = 535
    x0 = 30
    x1 = x0 + page_w

    # ── Outer border ──
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(dark)
    |> Pdf.set_line_width(1.5)
    |> Pdf.rectangle({x0, 30}, {page_w, 782})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # ── HEADER SECTION ──
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(orange)
    |> Pdf.set_line_width(2)
    |> Pdf.set_fill_color({1.0, 1.0, 1.0})
    |> Pdf.rectangle({x0 + 10, 745}, {100, 60})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 14)
    |> Pdf.set_fill_color(orange)
    |> Pdf.text_at({x0 + 30, 770}, "signati")
    |> Pdf.restore_state()

    # Company info
    doc = doc
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 120, 800}, "MARIA WATEMBER TORRES", %{bold: true})
    |> Pdf.text_at({x0 + 120, 789}, "R.F.C: WATM640917J45", %{bold: true})
    |> Pdf.text_at({x0 + 120, 778}, "REGIMEN: 612 - PERSONAS FISICAS CON", %{bold: true})
    |> Pdf.text_at({x0 + 120, 767}, "ACTIVIDADES EMPRESARIALES Y", %{bold: true})
    |> Pdf.text_at({x0 + 120, 756}, "PROFESIONALES", %{bold: true})
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({x0 + 120, 743}, "LUGAR DE EXPEDICION: CONSTITUYENTES y 115", %{bold: true})
    |> Pdf.text_at({x0 + 120, 733}, "AV MZA.25 LT.2 Y 3, EJIDO NORTE, 77714 PLAYA", %{bold: true})
    |> Pdf.text_at({x0 + 120, 723}, "DEL CARMEN, Q.R.", %{bold: true})

    # FACTURA box (right side)
    factura_x = x1 - 140
    doc = render_factura_box(doc, factura_x, dark, orange, header_bg, border_c)

    # ── DATOS DEL CLIENTE ──
    doc = render_client_data(doc, x0, x1, dark, orange, light_border)

    # ── ITEMS TABLE ──
    y_table = 652
    col_w = [55, 65, 195, 45, 60, 60, 55]
    doc = render_table(doc, x0, page_w, y_table, col_w, dark, header_bg, border_c, light_border)

    # ── TOTALS SECTION ──
    row_height = 70
    y_row_start = y_table - 14
    y_totals = y_row_start - 4 * row_height
    doc = render_totals(doc, x0, page_w, y_totals, dark, orange, border_c)

    # ── PAYMENT INFO ──
    y_pay = y_totals - 55
    doc = render_payment(doc, x0, x1, y_pay, dark, light_border)

    # ── CERTIFICATION INFO ──
    y_cert = y_pay - 45
    doc = render_certification(doc, x0, page_w, y_cert, dark, header_bg, border_c)

    # ── DIGITAL SEALS ──
    y_seal = y_cert - 62
    doc = render_seals(doc, x0, x1, y_seal, dark, border_c, light_border)

    # ── Footer ──
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.3)
    |> Pdf.line({x0, 42}, {x1, 42})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({x0 + 30, 34}, "by Signati")
  end

  defp render_factura_box(doc, fx, dark, orange, header_bg, border_c) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({fx, 795}, {130, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({fx, 795}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({fx + 40, 799}, "FACTURA", %{bold: true})
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({fx, 779}, {130, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({fx, 779}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({fx + 50, 783}, "FOLIO")
    |> Pdf.rectangle({fx, 763}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(orange)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.text_at({fx + 25, 767}, "A - MYLF-24", %{bold: true})
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({fx, 747}, {130, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({fx, 747}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({fx + 50, 751}, "FECHA")
    |> Pdf.set_stroke_color(orange)
    |> Pdf.set_line_width(1)
    |> Pdf.rectangle({fx, 731}, {130, 16})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(orange)
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({fx + 10, 735}, "2022-05-07T04:33:52", %{bold: true})
    |> Pdf.restore_state()
  end

  defp render_client_data(doc, x0, x1, dark, orange, light_border) do
    y_client = 708
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({x0, y_client + 5}, {x1, y_client + 5})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(orange)
    |> Pdf.text_at({x0 + 5, y_client - 5}, "Datos del Cliente", %{italic: true})
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.text_at({x0 + 5, y_client - 18}, "Razon Social: ", %{italic: true})
    |> Pdf.text_at({x0 + 75, y_client - 18}, "CALEB ISAAC MORA DIAZ", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_client - 30}, "R.F.C.: ", %{italic: true})
    |> Pdf.text_at({x0 + 42, y_client - 30}, "MODC980924HK1", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_client - 42}, "Uso CFDI: ", %{italic: true})
    |> Pdf.text_at({x0 + 52, y_client - 42}, "G03", %{bold: true})
  end

  defp render_table(doc, x0, page_w, y_table, col_w, dark, header_bg, border_c, light_border) do
    headers = ["CANTIDAD", "CLAVE SAT", "CONCEPTO/DESCRIPCION", "UNIDAD", "P.UNITARIO", "DESCUENTO", "IMPORTE"]

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({x0, y_table - 14}, {page_w, 16})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({x0, y_table - 14}, {page_w, 16})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)

    {doc, _} = Enum.reduce(Enum.zip(headers, col_w), {doc, x0}, fn {header, w}, {d, cx} ->
      d = Pdf.text_at(d, {cx + 3, y_table - 10}, header, %{bold: true})
      {d, cx + w}
    end)

    row_height = 70
    y_row_start = y_table - 14

    Enum.with_index(rows_data()) |> Enum.reduce(doc, fn {{cant, clave, desc_lines, unidad, precio, desc, importe}, idx}, d ->
      ry = y_row_start - (idx + 1) * row_height

      d = d
      |> Pdf.save_state()
      |> Pdf.set_stroke_color(light_border)
      |> Pdf.set_line_width(0.3)
      |> Pdf.rectangle({x0, ry}, {page_w, row_height})
      |> Pdf.stroke()
      |> Pdf.restore_state()
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({Enum.at(col_xs(x0, col_w), 0) + 20, ry + row_height - 12}, cant)

      d = Pdf.text_at(d, {Enum.at(col_xs(x0, col_w), 1) + 5, ry + row_height - 12}, clave)

      cx2 = Enum.at(col_xs(x0, col_w), 2)
      d = Enum.with_index(desc_lines) |> Enum.reduce(d, fn {line, li}, dd ->
        font_opts = if li == 0, do: %{bold: true}, else: %{}
        Pdf.text_at(dd, {cx2 + 3, ry + row_height - 12 - li * 10}, line, font_opts)
      end)

      d = Pdf.text_at(d, {Enum.at(col_xs(x0, col_w), 3) + 10, ry + row_height - 12}, unidad)
      d = Pdf.text_at(d, {Enum.at(col_xs(x0, col_w), 4) + 5, ry + row_height - 12}, precio)
      d = Pdf.text_at(d, {Enum.at(col_xs(x0, col_w), 5) + 10, ry + row_height - 12}, desc)
      Pdf.text_at(d, {Enum.at(col_xs(x0, col_w), 6) + 5, ry + row_height - 12}, importe)
    end)
  end

  defp render_totals(doc, x0, page_w, y_totals, dark, orange, border_c) do
    totals_x = x0 + page_w * 0.65
    totals_w = page_w * 0.35

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({x0, y_totals - 30}, {page_w * 0.65, 30})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 5, y_totals - 10}, "CANTIDAD CON LETRA", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_totals - 22}, "SETECIENTOS VEINTE PESOS 01/100 M.N")

    totals_data = [
      {"SUBTOTAL:", "$952.27"},
      {"DESCUENTO:", "$232.26"},
      {"IMPUESTOS:", "$"},
      {"TOTAL:", "$720.01"}
    ]

    Enum.with_index(totals_data) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      ty = y_totals - 2 - i * 11
      is_total = i == length(totals_data) - 1

      d = if is_total do
        d
        |> Pdf.save_state()
        |> Pdf.set_fill_color({1.0, 0.97, 0.9})
        |> Pdf.rectangle({totals_x, ty - 4}, {totals_w, 13})
        |> Pdf.fill()
        |> Pdf.restore_state()
      else
        d
      end

      d
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.set_fill_color(if(is_total, do: orange, else: dark))
      |> Pdf.text_at({totals_x + 5, ty}, label, %{bold: is_total})
      |> Pdf.text_at({totals_x + totals_w - 55, ty}, value, %{bold: is_total})
    end)
  end

  defp render_payment(doc, x0, x1, y_pay, dark, light_border) do
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.3)
    |> Pdf.line({x0, y_pay + 8}, {x1, y_pay + 8})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 5, y_pay - 5}, "Forma de pago: ")
    |> Pdf.text_at({x0 + 80, y_pay - 5}, "01 - Efectivo", %{bold: true})
    |> Pdf.text_at({x0 + 270, y_pay - 5}, "Moneda: ")
    |> Pdf.text_at({x0 + 310, y_pay - 5}, "MXN", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_pay - 16}, "Metodo de pago: ")
    |> Pdf.text_at({x0 + 85, y_pay - 16}, "PUE - Pago en una sola exhibicion", %{bold: true})
    |> Pdf.text_at({x0 + 270, y_pay - 16}, "Tipo de comprobante: ")
    |> Pdf.text_at({x0 + 375, y_pay - 16}, "I - Ingreso", %{bold: true})
    |> Pdf.text_at({x0 + 5, y_pay - 27}, "No. de cuenta:")
  end

  defp render_certification(doc, x0, page_w, y_cert, dark, header_bg, border_c) do
    cert_mid = x0 + page_w / 2
    hw = page_w / 2

    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({x0, y_cert}, {hw, 14})
    |> Pdf.fill()
    |> Pdf.rectangle({cert_mid, y_cert}, {hw, 14})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({x0, y_cert}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.text_at({x0 + 50, y_cert + 3}, "No. CSD del Emisor", %{bold: true})
    |> Pdf.text_at({cert_mid + 30, y_cert + 3}, "Fecha y hora de certificacion", %{bold: true})
    |> Pdf.rectangle({x0, y_cert - 14}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert - 14}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.text_at({x0 + 20, y_cert - 11}, "30001000000400002333")
    |> Pdf.text_at({cert_mid + 40, y_cert - 11}, "2022-05-07T16:32:00")
    |> Pdf.set_fill_color(header_bg)
    |> Pdf.rectangle({x0, y_cert - 28}, {hw, 14})
    |> Pdf.fill()
    |> Pdf.rectangle({cert_mid, y_cert - 28}, {hw, 14})
    |> Pdf.fill()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.rectangle({x0, y_cert - 28}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert - 28}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0 + 60, y_cert - 25}, "Folio Fiscal", %{bold: true})
    |> Pdf.text_at({cert_mid + 50, y_cert - 25}, "No. CSD del SAT", %{bold: true})
    |> Pdf.rectangle({x0, y_cert - 42}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.rectangle({cert_mid, y_cert - 42}, {hw, 14})
    |> Pdf.stroke()
    |> Pdf.set_font("Courier", 6)
    |> Pdf.text_at({x0 + 5, y_cert - 39}, "6CE88083-E455-458D-BE8D-2A292BC6DEEE")
    |> Pdf.text_at({cert_mid + 15, y_cert - 39}, "30001000000400002495")
    |> Pdf.restore_state()
  end

  defp render_seals(doc, x0, x1, y_seal, dark, border_c, light_border) do
    seal_x = x0 + 95

    seal_emisor = "gieMqNUlmQPBElJY3bmZHyFU3mtUh+Qk5V2yUBRa83y/AmcBnwrtDo9hb9qLY+NSu5mOoN67fubNwcWv72qW/YKdJEzzUNP" <>
      "+clpPJbxMerTmVhRm4dusX4hFdA6M6WW..."
    seal_sat = "pXWM0nAQ8+d31f/SVRqZwfb6XHQOndGQyNQ8hqySoqRevKZ/6bp5NN" <>
      "+0BhR04Jj03qLgr0obj5t.J8EuLBeQfMNZawH4xboNpUA34og9Mv7jAaHdagzw..."
    cadena = "||1.1|6ce88b0b3-e455-458d-be8d-2a292bc6deee|2022-05-07T16:32:00|SPR190631i3S2|gieMqNUlmQPBElJY3bmZHyFU3mtUh" <>
      "+Qk5V2yUBRa83y/AmcBnwrtDo9hb9qLY+NSu5mOoN67fubNwcWv72qW/YKdJEzz..."

    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.3)
    |> Pdf.line({x0, y_seal + 5}, {x1, y_seal + 5})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(border_c)
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle({x0 + 5, y_seal - 95}, {80, 80})
    |> Pdf.stroke()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({x0 + 25, y_seal - 55}, "[QR Code]")
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({seal_x, y_seal - 5}, "SELLO DIGITAL DEL EMISOR", %{bold: true})
    |> Pdf.set_font("Courier", 5)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({seal_x + 10, y_seal - 14}, seal_emisor)
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({seal_x, y_seal - 30}, "SELLO DEL SAT", %{bold: true})
    |> Pdf.set_font("Courier", 5)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({seal_x + 10, y_seal - 39}, seal_sat)
    |> Pdf.set_font("Helvetica", 7)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({seal_x, y_seal - 55}, "CADENA ORIGINAL DEL COMPLEMENTO DE CERTIFICACION DIGITAL DEL SAT", %{bold: true})
    |> Pdf.set_font("Courier", 5)
    |> Pdf.set_fill_color({0.3, 0.3, 0.3})
    |> Pdf.text_at({seal_x + 10, y_seal - 64}, cadena)
  end

  defp col_xs(x0, col_w) do
    Enum.scan([x0 | col_w], &(&1 + &2)) |> List.insert_at(0, x0)
  end

  defp rows_data do
    [
      {"1", "86121601", [
        "Mensualidad - octubre", "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1", "RFC: MODC980924HK1"
      ], "E48", "$232.26", "$232.26", "$232.26"},
      {"1", "86121601", [
        "Mensualidad - noviembre", "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1", "RFC: MODC980924HK1"
      ], "E48", "$232.26", "$0.00", "$232.26"},
      {"1", "86121601", [
        "Mensualidad - diciembre", "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1", "RFC: MODC980924HK1"
      ], "E48", "$255.49", "$0.00", "$255.49"},
      {"1", "86121601", [
        "Mensualidad - enero", "ALUMNO: PUBLICO GENERAL",
        "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA",
        "CLAVE: C1", "RFC: MODC980924HK1"
      ], "E48", "$232.26", "$0.00", "$232.26"}
    ]
  end
end
