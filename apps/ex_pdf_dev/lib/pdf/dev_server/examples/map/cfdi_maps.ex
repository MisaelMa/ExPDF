defmodule Pdf.DevServer.Examples.Map.CfdiMaps do
  @moduledoc false

  def render do
    # Colors
    dark = {0.2, 0.2, 0.2}
    orange = {0.9, 0.55, 0.0}
    header_bg = {0.95, 0.95, 0.95}
    border_c = {0.4, 0.4, 0.4}
    light_border = {0.7, 0.7, 0.7}

    # Reusable text styles
    company = %{font_size: 9, bold: true, color: dark}
    company_sm = %{font_size: 8, bold: true, color: dark}
    lbl = %{font_size: 9, italic: true, color: dark}
    val = %{font_size: 9, bold: true, color: dark}
    seal_font = %{font: "Courier", font_size: 5, color: {0.3, 0.3, 0.3}}
    seal_label = %{font_size: 7, bold: true, color: dark}
    cert_font = %{font_size: 7, color: dark}
    cert_bold = %{font_size: 7, bold: true, color: dark}
    pay = %{font_size: 8, color: dark}
    pay_b = %{font_size: 8, bold: true, color: dark}

    # Layout constants
    x0 = 30
    pw = 535
    x1 = x0 + pw
    cx = x0 + 120
    fx = x1 - 140
    yt = 652
    col_w = [55, 65, 195, 45, 60, 60, 55]
    rh = 70
    yrs = yt - 14
    y_tot = yrs - 4 * rh
    tx = x0 + pw * 0.65
    tw = pw * 0.35
    yp = y_tot - 55
    ycc = yp - 45
    cm = x0 + pw / 2
    hw = pw / 2
    ys = ycc - 62
    sx = x0 + 95

    config = %{
      size: :a4,
      margin: %{top: 30, bottom: 30, left: 30, right: 30},
      font: "Helvetica",
      font_size: 9
    }

    rows = rows_data()

    cell = %{font_size: 8, color: dark}
    hdr = %{font_size: 7, bold: true, color: dark}
    col_xs = Enum.scan([x0 | col_w], &(&1 + &2)) |> List.insert_at(0, x0)

    template = [
      # ── Outer border ──
      %{rect: {x0, 30}, size: {pw, 782}, stroke: dark, line_width: 1.5},

      # ── Logo placeholder ──
      %{rect: {x0 + 10, 745}, size: {100, 60}, stroke: orange, line_width: 2},
      %{text: "signati", font_size: 14, bold: true, color: orange, x: x0 + 30, y: 770},

      # ── Company info ──
      Map.merge(company, %{text: "MARIA WATEMBER TORRES", x: cx, y: 800}),
      Map.merge(company, %{text: "R.F.C: WATM640917J45", x: cx, y: 789}),
      Map.merge(company, %{text: "REGIMEN: 612 - PERSONAS FISICAS CON", x: cx, y: 778}),
      Map.merge(company, %{text: "ACTIVIDADES EMPRESARIALES Y", x: cx, y: 767}),
      Map.merge(company, %{text: "PROFESIONALES", x: cx, y: 756}),
      Map.merge(company_sm, %{text: "LUGAR DE EXPEDICION: CONSTITUYENTES y 115", x: cx, y: 743}),
      Map.merge(company_sm, %{text: "AV MZA.25 LT.2 Y 3, EJIDO NORTE, 77714 PLAYA", x: cx, y: 733}),
      Map.merge(company_sm, %{text: "DEL CARMEN, Q.R.", x: cx, y: 723}),

      # ── FACTURA box (right side) ──
      %{rect: {fx, 795}, size: {130, 16}, fill: header_bg, stroke: border_c},
      %{rect: {fx, 779}, size: {130, 16}, fill: header_bg, stroke: border_c},
      %{rect: {fx, 763}, size: {130, 16}, stroke: border_c},
      %{rect: {fx, 747}, size: {130, 16}, fill: header_bg, stroke: border_c},
      %{rect: {fx, 731}, size: {130, 16}, stroke: orange, line_width: 1},
      %{text: "FACTURA", font_size: 10, bold: true, color: dark, x: fx + 40, y: 799},
      %{text: "FOLIO", font_size: 8, color: dark, x: fx + 50, y: 783},
      %{text: "A - MYLF-24", font_size: 9, bold: true, color: orange, x: fx + 25, y: 767},
      %{text: "FECHA", font_size: 8, color: dark, x: fx + 50, y: 751},
      %{text: "2022-05-07T04:33:52", font_size: 8, bold: true, color: orange, x: fx + 10, y: 735},

      # ── DATOS DEL CLIENTE ──
      %{line_from: {x0, 713}, line_to: {x1, 713}, stroke: light_border},
      %{text: "Datos del Cliente", font_size: 10, italic: true, color: orange, x: x0 + 5, y: 703},
      Map.merge(lbl, %{text: "Razon Social: ", x: x0 + 5, y: 690}),
      Map.merge(val, %{text: "CALEB ISAAC MORA DIAZ", x: x0 + 75, y: 690}),
      Map.merge(lbl, %{text: "R.F.C.: ", x: x0 + 5, y: 678}),
      Map.merge(val, %{text: "MODC980924HK1", x: x0 + 42, y: 678}),
      Map.merge(lbl, %{text: "Uso CFDI: ", x: x0 + 5, y: 666}),
      Map.merge(val, %{text: "G03", x: x0 + 52, y: 666}),

      # ── ITEMS TABLE header ──
      %{rect: {x0, yt - 14}, size: {pw, 16}, fill: header_bg, stroke: border_c},
      Enum.zip(["CANTIDAD", "CLAVE SAT", "CONCEPTO/DESCRIPCION", "UNIDAD", "P.UNITARIO", "DESCUENTO", "IMPORTE"], col_xs)
      |> Enum.map(fn {h, cxx} -> Map.merge(hdr, %{text: h, x: cxx + 3, y: yt - 10}) end),

      # ── Table rows ──
      Enum.with_index(rows) |> Enum.flat_map(fn {{cant, clave, descs, unidad, precio, desc, importe}, idx} ->
        ry = yrs - (idx + 1) * rh
        ty = ry + rh - 12
        [
          %{rect: {x0, ry}, size: {pw, rh}, stroke: light_border, line_width: 0.3},
          Map.merge(cell, %{text: cant, x: Enum.at(col_xs, 0) + 20, y: ty}),
          Map.merge(cell, %{text: clave, x: Enum.at(col_xs, 1) + 5, y: ty}),
          Enum.with_index(descs) |> Enum.map(fn {line, li} ->
            s = if(li == 0, do: %{bold: true}, else: %{})
            Map.merge(cell, Map.merge(s, %{text: line, x: Enum.at(col_xs, 2) + 3, y: ty - li * 10}))
          end),
          Map.merge(cell, %{text: unidad, x: Enum.at(col_xs, 3) + 10, y: ty}),
          Map.merge(cell, %{text: precio, x: Enum.at(col_xs, 4) + 5, y: ty}),
          Map.merge(cell, %{text: desc, x: Enum.at(col_xs, 5) + 10, y: ty}),
          Map.merge(cell, %{text: importe, x: Enum.at(col_xs, 6) + 5, y: ty})
        ]
      end),

      # ── TOTALS ──
      %{rect: {x0, y_tot - 30}, size: {pw * 0.65, 30}, stroke: border_c},
      %{text: "CANTIDAD CON LETRA", font_size: 8, bold: true, color: dark, x: x0 + 5, y: y_tot - 10},
      %{text: "SETECIENTOS VEINTE PESOS 01/100 M.N", font_size: 8, color: dark, x: x0 + 5, y: y_tot - 22},
      Enum.with_index([{"SUBTOTAL:", "$952.27"}, {"DESCUENTO:", "$232.26"}, {"IMPUESTOS:", "$"}, {"TOTAL:", "$720.01"}])
      |> Enum.flat_map(fn {{l, v}, i} ->
        ty = y_tot - 2 - i * 11
        is_t = i == 3
        c = if(is_t, do: orange, else: dark)
        highlight = if(is_t, do: [%{rect: {tx, ty - 4}, size: {tw, 13}, fill: {1.0, 0.97, 0.9}}], else: [])
        highlight ++ [
          %{text: l, font_size: 8, bold: is_t, color: c, x: tx + 5, y: ty},
          %{text: v, font_size: 8, bold: is_t, color: c, x: tx + tw - 55, y: ty}
        ]
      end),

      # ── PAYMENT INFO ──
      %{line_from: {x0, yp + 8}, line_to: {x1, yp + 8}, stroke: light_border, line_width: 0.3},
      Map.merge(pay, %{text: "Forma de pago: ", x: x0 + 5, y: yp - 5}),
      Map.merge(pay_b, %{text: "01 - Efectivo", x: x0 + 80, y: yp - 5}),
      Map.merge(pay, %{text: "Moneda: ", x: x0 + 270, y: yp - 5}),
      Map.merge(pay_b, %{text: "MXN", x: x0 + 310, y: yp - 5}),
      Map.merge(pay, %{text: "Metodo de pago: ", x: x0 + 5, y: yp - 16}),
      Map.merge(pay_b, %{text: "PUE - Pago en una sola exhibicion", x: x0 + 85, y: yp - 16}),
      Map.merge(pay, %{text: "Tipo de comprobante: ", x: x0 + 270, y: yp - 16}),
      Map.merge(pay_b, %{text: "I - Ingreso", x: x0 + 375, y: yp - 16}),
      Map.merge(pay, %{text: "No. de cuenta:", x: x0 + 5, y: yp - 27}),

      # ── CERTIFICATION ──
      %{rect: {x0, ycc}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {cm, ycc}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {x0, ycc - 14}, size: {hw, 14}, stroke: border_c},
      %{rect: {cm, ycc - 14}, size: {hw, 14}, stroke: border_c},
      %{rect: {x0, ycc - 28}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {cm, ycc - 28}, size: {hw, 14}, fill: header_bg, stroke: border_c},
      %{rect: {x0, ycc - 42}, size: {hw, 14}, stroke: border_c},
      %{rect: {cm, ycc - 42}, size: {hw, 14}, stroke: border_c},
      Map.merge(cert_bold, %{text: "No. CSD del Emisor", x: x0 + 50, y: ycc + 3}),
      Map.merge(cert_bold, %{text: "Fecha y hora de certificacion", x: cm + 30, y: ycc + 3}),
      Map.merge(cert_font, %{text: "30001000000400002333", x: x0 + 20, y: ycc - 11}),
      Map.merge(cert_font, %{text: "2022-05-07T16:32:00", x: cm + 40, y: ycc - 11}),
      Map.merge(cert_bold, %{text: "Folio Fiscal", x: x0 + 60, y: ycc - 25}),
      Map.merge(cert_bold, %{text: "No. CSD del SAT", x: cm + 50, y: ycc - 25}),
      %{text: "6CE88083-E455-458D-BE8D-2A292BC6DEEE", font: "Courier", font_size: 6, color: dark, x: x0 + 5, y: ycc - 39},
      %{text: "30001000000400002495", font: "Courier", font_size: 6, color: dark, x: cm + 15, y: ycc - 39},

      # ── DIGITAL SEALS ──
      %{line_from: {x0, ys + 5}, line_to: {x1, ys + 5}, stroke: light_border, line_width: 0.3},
      %{rect: {x0 + 5, ys - 95}, size: {80, 80}, stroke: border_c},
      %{text: "[QR Code]", font_size: 7, color: :gray, x: x0 + 25, y: ys - 55},
      Map.merge(seal_label, %{text: "SELLO DIGITAL DEL EMISOR", x: sx, y: ys - 5}),
      Map.merge(seal_font, %{text: "gieMqNUlmQPBElJY3bmZHyFU3mtUh+Qk5V2yUBRa83y/AmcBnwrtDo9hb9qLY...", x: sx + 10, y: ys - 14}),
      Map.merge(seal_label, %{text: "SELLO DEL SAT", x: sx, y: ys - 30}),
      Map.merge(seal_font, %{text: "pXWM0nAQ8+d31f/SVRqZwfb6XHQOndGQyNQ8hqySoqRevKZ/6bp5NN...", x: sx + 10, y: ys - 39}),
      Map.merge(seal_label, %{text: "CADENA ORIGINAL DEL COMPLEMENTO DE CERTIFICACION DIGITAL DEL SAT", x: sx, y: ys - 55}),
      Map.merge(seal_font, %{text: "||1.1|6ce88b0b3-e455-458d-be8d-2a292bc6deee|2022-05-07T16:32:00|SPR190631i3S2...", x: sx + 10, y: ys - 64}),

      # ── Footer ──
      %{line_from: {x0, 42}, line_to: {x1, 42}, stroke: light_border, line_width: 0.3},
      %{text: "by Signati", font_size: 7, color: :gray, x: x0 + 30, y: 34}
    ]

    Pdf.Builder.render(template, config)
  end

  defp rows_data do
    [
      {"1", "86121601", ["Mensualidad - octubre", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$232.26", "$232.26", "$232.26"},
      {"1", "86121601", ["Mensualidad - noviembre", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$232.26", "$0.00", "$232.26"},
      {"1", "86121601", ["Mensualidad - diciembre", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$255.49", "$0.00", "$255.49"},
      {"1", "86121601", ["Mensualidad - enero", "ALUMNO: PUBLICO GENERAL", "CURP: MACA961017HQRRHM06", "NIVEL EDUCATIVO: PRIMARIA", "CLAVE: C1", "RFC: MODC980924HK1"], "E48", "$232.26", "$0.00", "$232.26"}
    ]
  end
end
