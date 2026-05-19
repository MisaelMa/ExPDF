defmodule Pdf.DevServer.Examples.Map.RvMaps do
  @moduledoc false

  def render do
    # Colors
    dark = {0.1, 0.1, 0.1}
    teal = {0.0, 0.65, 0.63}
    gray = {0.5, 0.5, 0.5}
    light_border = {0.82, 0.82, 0.82}

    # Reusable text styles
    title_s = %{font_size: 22, bold: true, color: dark}
    brand_s = %{font_size: 20, bold: true, color: teal}
    heading = %{font_size: 16, bold: true, color: dark}
    normal = %{font_size: 9, color: dark}
    normal10 = %{font_size: 10, color: dark}
    bold10 = %{font_size: 10, bold: true, color: dark}
    small_gray = %{font_size: 8, color: gray}
    info_bold = %{font_size: 10, bold: true, color: dark}
    info_gray = %{font_size: 9, color: gray}

    # Layout constants
    x0 = 50
    pw = 495
    x1 = x0 + pw
    lw = 230
    rx = x0 + lw + 15
    rw = pw - lw - 15
    by = 750
    py = 750
    d1y = py - 90
    d2y = d1y - 52
    pay_y = py - 170 - 15
    ay = pay_y - 65
    ix = x0 + 95

    config = %{
      size: :a4,
      margin: %{top: 0, bottom: 0, left: 0, right: 0},
      font: "Helvetica",
      font_size: 10
    }

    details = [
      {"Reservation ID:", "38111"},
      {"Site Location:", "Spot: 059"},
      {"Check-in:", "June 7, 2026"},
      {"Check-out:", "June 10, 2026"},
      {"Guest:", "2 adults, 1 pet"},
      {"RV Profile:", "Fifth Wheel, 45 feet"}
    ]

    detail_row_h = 16
    header_h = 95
    bottom_pad = 12
    left_box_h = header_h + length(details) * detail_row_h + bottom_pad

    prices = [{"3rd Party Calculated Tax", "$16.61"}, {"Klamath Falls RV Resort ($60.50 x 3)", "$181.49"}]
    subs = [{"Subtotal", "$198.10"}, {"Service Fee", "$17.48"}]

    template = [
      # ── Background ──
      %{rect: {0, 0}, size: {595, 842}, fill: {0.97, 0.97, 0.97}},
      %{rect: {x0 - 15, 40}, size: {pw + 30, 770}, fill: {1.0, 1.0, 1.0}, border_radius: 5},

      # ── Title row ──
      Map.merge(title_s, %{text: "Your receipt from Spot2Nite", x: x0, y: 785}),
      Map.merge(brand_s, %{text: "SPOT2NITE", x: x1 - 115, y: 785}),

      # ── Left box border + image placeholder ──
      %{rect: {x0, by - left_box_h}, size: {lw, left_box_h}, stroke: light_border, line_width: 0.8, border_radius: 5},
      %{rect: {x0 + 8, by - 75}, size: {80, 65}, fill: {0.88, 0.91, 0.88}, border_radius: 5},
      %{text: "[Photo]", font_size: 6, color: gray, x: x0 + 25, y: by - 45},

      # ── Resort info ──
      Map.merge(info_bold, %{text: "Klamath Falls RV Resort", x: ix, y: by - 18}),
      Map.merge(info_gray, %{text: "Klamath Falls", x: ix, y: by - 30}),
      Map.merge(info_gray, %{text: "(541) 414-6657", x: ix, y: by - 41}),
      Map.merge(info_gray, %{text: "Klamath@rjourney.com", x: ix, y: by - 52}),

      # ── Reservation details ──
      Enum.with_index(details) |> Enum.flat_map(fn {{l, v}, i} ->
        ly = by - 95 - i * 16
        [
          Map.merge(bold10, %{text: l, x: x0 + 10, y: ly}),
          Map.merge(normal10, %{text: v, x: x0 + lw - 10 - estimate_width(v, 10), y: ly})
        ]
      end),

      # ── Price breakdown box ──
      %{rect: {rx, py - 170}, size: {rw, 170}, stroke: light_border, line_width: 0.8, border_radius: 5},
      Map.merge(heading, %{text: "Price breakdown", x: rx + 12, y: py - 22}),

      # Price items
      Enum.with_index(prices) |> Enum.flat_map(fn {{l, v}, i} ->
        y = py - 48 - i * 18
        [
          Map.merge(normal, %{text: l, x: rx + 12, y: y}),
          Map.merge(normal, %{text: v, x: rx + rw - 12 - estimate_width(v, 9), y: y})
        ]
      end),

      # Divider
      %{line_from: {rx + 10, d1y}, line_to: {rx + rw - 10, d1y}, stroke: light_border},

      # Subtotal / Service Fee
      Enum.with_index(subs) |> Enum.flat_map(fn {{l, v}, i} ->
        y = d1y - 16 - i * 16
        [
          Map.merge(normal, %{text: l, x: rx + 12, y: y}),
          Map.merge(normal, %{text: v, x: rx + rw - 12 - estimate_width(v, 9), y: y})
        ]
      end),

      # Divider + Total
      %{line_from: {rx + 10, d2y}, line_to: {rx + rw - 10, d2y}, stroke: light_border},
      Map.merge(bold10, %{text: "Total (USD)", x: rx + 12, y: d2y - 16}),
      Map.merge(bold10, %{text: "$215.58", x: rx + rw - 12 - estimate_width("$215.58", 10), y: d2y - 16}),

      # ── Payment box ──
      %{rect: {rx, pay_y - 95}, size: {rw, 95}, stroke: light_border, line_width: 0.8, border_radius: 5},
      Map.merge(heading, %{text: "Payment", x: rx + 12, y: pay_y - 22}),
      Map.merge(normal10, %{text: "VISA... 2060", x: rx + 12, y: pay_y - 44}),
      Map.merge(bold10, %{text: "$215.58", x: rx + rw - 12 - estimate_width("$215.58", 10), y: pay_y - 44}),
      Map.merge(small_gray, %{text: "Mar 30, 2026 - 8:47:59 PM", x: rx + 12, y: pay_y - 56}),

      # Divider + Amount paid
      %{line_from: {rx + 10, ay}, line_to: {rx + rw - 10, ay}, stroke: light_border},
      Map.merge(bold10, %{text: "Amount paid (USD)", x: rx + 12, y: ay - 16}),
      Map.merge(bold10, %{text: "$215.58", x: rx + rw - 12 - estimate_width("$215.58", 10), y: ay - 16})
    ]

    Pdf.Builder.render(template, config)
  end

  defp estimate_width(text, font_size) do
    String.length(text) * font_size * 0.52
  end
end
