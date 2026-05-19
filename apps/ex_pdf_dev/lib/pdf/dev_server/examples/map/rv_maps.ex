defmodule Pdf.DevServer.Examples.Map.RvMaps do
  @moduledoc """
  RV receipt using cursor-based positioning + components.

  Margin in config controls the outer spacing.
  Uses Box for containers, KeyValue for detail pairs.
  All layout flows from the cursor — no hardcoded y coordinates.
  """

  def render do
    # Colors
    dark = {0.1, 0.1, 0.1}
    teal = {0.0, 0.65, 0.63}
    gray = {0.5, 0.5, 0.5}
    border = {0.82, 0.82, 0.82}

    # Reusable text styles
    title_s = %{font_size: 22, bold: true, color: dark}
    brand_s = %{font_size: 20, bold: true, color: teal}
    heading = %{font_size: 16, bold: true, color: dark}
    small_gray = %{font_size: 8, color: gray}

    # ── Data ──
    details = [
      {"Reservation ID:", "38111"},
      {"Site Location:", "Spot: 059"},
      {"Check-in:", "June 7, 2026"},
      {"Check-out:", "June 10, 2026"},
      {"Guest:", "2 adults, 1 pet"},
      {"RV Profile:", "Fifth Wheel, 45 feet"}
    ]

    prices = [
      {"3rd Party Calculated Tax", "$16.61"},
      {"Klamath Falls RV Resort ($60.50 x 3)", "$181.49"}
    ]
    subs = [{"Subtotal", "$198.10"}, {"Service Fee", "$17.48"}]

    # ── Dynamic sizes ──
    lw = 230
    rw = 250
    pad = 10
    kv_line_h = 16
    resort_header_h = 65
    left_box_h = resort_header_h + length(details) * kv_line_h + pad * 3
    price_box_h = 170
    pay_box_h = 95
    box_gap = 15
    row_h = max(left_box_h, price_box_h + box_gap + pay_box_h)

    # ── Config — margin controls all spacing ──
    config = %{
      size: :a4,
      margin: %{top: 40, bottom: 30, left: 50, right: 50},
      font: "Helvetica",
      font_size: 10
    }

    # ── Left: Resort info box with KeyValue details ──
    left_children = [
      %{box: {0, 0}, size: {lw, left_box_h},
        border: 0.8, border_color: border, border_radius: 5, padding: pad,
        children: [
          # Resort photo via Avatar component
          %{avatar: {0, 0},
            size: resort_header_h - pad,
            image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
            border_radius: :rounded},
          # Resort info text
          %{text: "Klamath Falls RV Resort", x: 85, y: -8, font_size: 10, bold: true, color: dark},
          %{text: "Klamath Falls", x: 85, y: -20, font_size: 9, color: gray},
          %{text: "(541) 414-6657", x: 85, y: -31, font_size: 9, color: gray},
          %{text: "Klamath@rjourney.com", x: 85, y: -42, font_size: 9, color: gray},
          # Reservation details via KeyValue component
          %{key_value: {0, -(resort_header_h + 2)},
            pairs: details,
            width: lw - pad * 2,
            font_size: 10,
            label_color: dark,
            value_color: dark,
            line_height: kv_line_h,
            label_width: 0.55,
            value_align: :right}
        ]}
    ]

    # ── Right: Price breakdown box ──
    price_children = [
      %{box: {0, 0}, size: {rw, price_box_h},
        border: 0.8, border_color: border, border_radius: 5, padding: pad,
        children: [
          Map.merge(heading, %{text: "Price breakdown", x: 2, y: -6}),
          # Price items via KeyValue
          %{key_value: {2, -38},
            pairs: prices,
            width: rw - pad * 2 - 4,
            font_size: 9,
            label_color: dark,
            value_color: dark,
            line_height: 18,
            label_bold: false,
            value_align: :right},
          # Divider
          %{line_from: {0, -80}, line_to: {rw - pad * 2, -80}, stroke: border},
          # Subtotals via KeyValue
          %{key_value: {2, -96},
            pairs: subs,
            width: rw - pad * 2 - 4,
            font_size: 9,
            label_color: dark,
            value_color: dark,
            line_height: 16,
            label_bold: false,
            value_align: :right},
          # Divider
          %{line_from: {0, -132}, line_to: {rw - pad * 2, -132}, stroke: border},
          # Total
          %{key_value: {2, -148},
            pairs: [{"Total (USD)", "$215.58"}],
            width: rw - pad * 2 - 4,
            font_size: 10,
            label_color: dark,
            value_color: dark,
            value_align: :right,
            value_bold: true}
        ]}
    ]

    # ── Right: Payment box ──
    payment_children = [
      %{box: {0, -(price_box_h + box_gap)}, size: {rw, pay_box_h},
        border: 0.8, border_color: border, border_radius: 5, padding: pad,
        children: [
          Map.merge(heading, %{text: "Payment", x: 2, y: -6}),
          %{key_value: {2, -28},
            pairs: [{"VISA... 2060", "$215.58"}],
            width: rw - pad * 2 - 4,
            font_size: 10,
            label_color: dark, label_bold: false,
            value_color: dark, value_bold: true,
            value_align: :right},
          Map.merge(small_gray, %{text: "Mar 30, 2026 - 8:47:59 PM", x: 2, y: -40}),
          %{line_from: {0, -49}, line_to: {rw - pad * 2, -49}, stroke: border},
          %{key_value: {2, -65},
            pairs: [{"Amount paid (USD)", "$215.58"}],
            width: rw - pad * 2 - 4,
            font_size: 10,
            label_color: dark,
            value_color: dark,
            value_align: :right,
            value_bold: true}
        ]}
    ]

    # ── Template — everything flows from cursor ──
    template = [
      # Title row
      %{row: :cursor, size: {:full, 30}, children: [
        {3, [Map.merge(title_s, %{text: "Your receipt from Spot2Nite", x: 0, y: -22})]},
        {1, [Map.merge(brand_s, %{text: "SPOT2NITE", x: 0, y: -22})]}
      ]},

      %{spacer: 5},

      # Main two-column layout
      %{row: :cursor, size: {:full, row_h}, gap: 15, children: [
        {lw, left_children},
        {rw, price_children ++ payment_children}
      ]}
    ]

    Pdf.Builder.render(template, config)
  end

end
