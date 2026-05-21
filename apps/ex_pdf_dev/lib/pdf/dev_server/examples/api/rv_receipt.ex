defmodule Pdf.DevServer.Examples.Api.RvReceipt do
  @moduledoc false

  def render do
    dark = {0.1, 0.1, 0.1}
    teal = {0.0, 0.65, 0.63}
    gray = {0.5, 0.5, 0.5}
    light_border = {0.82, 0.82, 0.82}
    bg_white = {1.0, 1.0, 1.0}

    doc = Pdf.new(size: :a4, margin: %{top: 10, bottom: 10, left: 0, right: 0})
    |> Pdf.set_info(title: "RV Resort Receipt")

    x0 = 50
    page_w = 495
    x1 = x0 + page_w

    # ── Background ──
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color({0.97, 0.97, 0.97})
    |> Pdf.rectangle({0, 0}, {595, 842})
    |> Pdf.fill()
    |> Pdf.set_fill_color(bg_white)
    |> Pdf.rectangle({x0 - 15, 40}, {page_w + 30, 770})
    |> Pdf.fill()
    |> Pdf.restore_state()

    # ── Title ──
    doc = doc
    |> Pdf.set_font("Helvetica", 22)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({x0, 785}, "Your receipt from Pine Valley RV", %{bold: true})
    |> Pdf.set_font("Helvetica", 20)
    |> Pdf.set_fill_color(teal)
    |> Pdf.text_at({x1 - 115, 785}, "PINE VALLEY", %{bold: true})

    # ── LEFT COLUMN ──
    left_w = 230
    left_x = x0
    box_y = 750

    # Reservation details
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
    box_h = header_h + length(details) * detail_row_h + bottom_pad

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.8)
    |> Pdf.rectangle({left_x, box_y - box_h}, {left_w, box_h})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Image placeholder
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_fill_color({0.88, 0.91, 0.88})
    |> Pdf.rectangle({left_x + 8, box_y - 75}, {80, 65})
    |> Pdf.fill()
    |> Pdf.set_font("Helvetica", 6)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({left_x + 25, box_y - 45}, "[Photo]")
    |> Pdf.restore_state()

    # Resort info
    info_x = left_x + 95
    doc = doc
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({info_x, box_y - 18}, "Klamath Falls RV Resort", %{bold: true})
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({info_x, box_y - 30}, "Klamath Falls")
    |> Pdf.text_at({info_x, box_y - 41}, "(541) 414-6657")
    |> Pdf.text_at({info_x, box_y - 52}, "Klamath@rjourney.com")

    # Reservation details
    detail_y = box_y - header_h
    doc = Enum.with_index(details) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      ly = detail_y - i * detail_row_h
      d
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({left_x + 10, ly}, label, %{bold: true})
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({left_x + left_w - 10 - estimate_width(value, 10), ly}, value)
    end)

    # ── RIGHT COLUMN ──
    right_x = left_x + left_w + 15
    right_w = page_w - left_w - 15

    # ── Price breakdown box ──
    price_y = 750
    price_h = 170

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.8)
    |> Pdf.rectangle({right_x, price_y - price_h}, {right_w, price_h})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 16)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, price_y - 22}, "Price breakdown", %{bold: true})

    price_items = [
      {"3rd Party Calculated Tax", "$16.61"},
      {"Klamath Falls RV Resort ($60.50 x 3)", "$181.49"}
    ]

    doc = Enum.with_index(price_items) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      py = price_y - 48 - i * 18
      d
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({right_x + 12, py}, label)
      |> Pdf.text_at({right_x + right_w - 12 - estimate_width(value, 9), py}, value)
    end)

    # Divider
    div_y = price_y - 90
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({right_x + 10, div_y}, {right_x + right_w - 10, div_y})
    |> Pdf.stroke()
    |> Pdf.restore_state()

    # Subtotal / Service Fee
    sub_items = [{"Subtotal", "$198.10"}, {"Service Fee", "$17.48"}]

    doc = Enum.with_index(sub_items) |> Enum.reduce(doc, fn {{label, value}, i}, d ->
      sy = div_y - 16 - i * 16
      d
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(dark)
      |> Pdf.text_at({right_x + 12, sy}, label)
      |> Pdf.text_at({right_x + right_w - 12 - estimate_width(value, 9), sy}, value)
    end)

    # Divider + Total
    div2_y = div_y - 52
    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({right_x + 10, div2_y}, {right_x + right_w - 10, div2_y})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, div2_y - 16}, "Total (USD)", %{bold: true})
    |> Pdf.text_at({right_x + right_w - 12 - estimate_width("$215.58", 10), div2_y - 16}, "$215.58", %{bold: true})

    # ── Payment box ──
    pay_y = price_y - price_h - 15
    pay_h = 95

    doc = doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.8)
    |> Pdf.rectangle({right_x, pay_y - pay_h}, {right_w, pay_h})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 16)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, pay_y - 22}, "Payment", %{bold: true})
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, pay_y - 44}, "VISA... 2060")
    |> Pdf.text_at({right_x + right_w - 12 - estimate_width("$215.58", 10), pay_y - 44}, "$215.58", %{bold: true})
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(gray)
    |> Pdf.text_at({right_x + 12, pay_y - 56}, "Mar 30, 2026 - 8:47:59 PM")

    # Divider + Amount paid
    apd_y = pay_y - 65
    doc
    |> Pdf.save_state()
    |> Pdf.set_stroke_color(light_border)
    |> Pdf.set_line_width(0.5)
    |> Pdf.line({right_x + 10, apd_y}, {right_x + right_w - 10, apd_y})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.set_fill_color(dark)
    |> Pdf.text_at({right_x + 12, apd_y - 16}, "Amount paid (USD)", %{bold: true})
    |> Pdf.text_at({right_x + right_w - 12 - estimate_width("$215.58", 10), apd_y - 16}, "$215.58", %{bold: true})
  end

  defp estimate_width(text, font_size) do
    String.length(text) * font_size * 0.52
  end
end
