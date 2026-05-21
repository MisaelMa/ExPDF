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
    alquileres = [
      %{
        name: "Klamath Falls RV Resort",
        location: "Klamath Falls",
        phone: "(541) 414-6657",
        email: "Klamath@rjourney.com",
        image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
        details: [
          {"Reservation ID:", "38111"},
          {"Site Location:", "Spot: 059"},
          {"Check-in:", "June 7, 2026"},
          {"Check-out:", "June 10, 2026"},
          {"Guest:", [
            %{text: "2 adults,", color: dark},
            %{text: "1 pet,", color: teal},
            %{text: "2 adults,", color: dark},
            %{text: "1 pet,", color: teal},
            %{text: "2 adults,", color: dark},
            %{text: "1 pet", color: teal}
          ]},
          {"RV Profile:", "Fifth Wheel, 45 feet"}
        ]
      },
      %{
        name: "Crater Lake RV Park",
        location: "Crater Lake",
        phone: "(541) 555-1234",
        email: "info@craterlake-rv.com",
        image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
        details: [
          {"Reservation ID:", "38225"},
          {"Site Location:", "Spot: 112"},
          {"Check-in:", "June 11, 2026"},
          {"Check-out:", "June 14, 2026"},
          {"Guest:", "2 adults, 1 pet"},
          {"RV Profile:", "Fifth Wheel, 45 feet"}
        ]
      },
      %{
        name: "Crater Lake RV Park",
        location: "Crater Lake",
        phone: "(541) 555-1234",
        email: "info@craterlake-rv.com",
        image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
        details: [
          {"Reservation ID:", "38225"},
          {"Site Location:", "Spot: 112"},
          {"Check-in:", "June 11, 2026"},
          {"Check-out:", "June 14, 2026"},
          {"Guest:", "2 adults, 1 pet"},
          {"RV Profile:", "Fifth Wheel, 45 feet"}
        ]
      },
      %{
        name: "Crater Lake RV Park",
        location: "Crater Lake",
        phone: "(541) 555-1234",
        email: "info@craterlake-rv.com",
        image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
        details: [
          {"Reservation ID:", "38225"},
          {"Site Location:", "Spot: 112"},
          {"Check-in:", "June 11, 2026"},
          {"Check-out:", "June 14, 2026"},
          {"Guest:", "2 adults, 1 pet"},
          {"RV Profile:", "Fifth Wheel, 45 feet"}
        ]
      },
      %{
        name: "Crater Lake RV Park",
        location: "Crater Lake",
        phone: "(541) 555-1234",
        email: "info@craterlake-rv.com",
        image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
        details: [
          {"Reservation ID:", "38225"},
          {"Site Location:", "Spot: 112"},
          {"Check-in:", "June 11, 2026"},
          {"Check-out:", "June 14, 2026"},
          {"Guest:", "2 adults, 1 pet"},
          {"RV Profile:", "Fifth Wheel, 45 feet"}
        ]
      },
      %{
        name: "Crater Lake RV Park",
        location: "Crater Lake",
        phone: "(541) 555-1234",
        email: "info@craterlake-rv.com",
        image: "https://media.gettyimages.com/id/175413610/es/foto/cami%C3%B3n-de-conversi%C3%B3n-de-veh%C3%ADculos-recreativos.jpg?s=612x612&w=gi&k=20&c=r3_cge3isSTnjTcOrnfiRTvxLLe2h_JFOy1QJFqdRuU=",
        details: [
          {"Reservation ID:", "38225"},
          {"Site Location:", "Spot: 112"},
          {"Check-in:", "June 11, 2026"},
          {"Check-out:", "June 14, 2026"},
          {"Guest:", "2 adults, 1 pet"},
          {"RV Profile:", "Fifth Wheel, 45 feet"}
        ]
      }
    ]

    prices = [
      {"3rd Party Calculated Tax", "$16.61"},
      {"Klamath Falls RV Resort ($60.50 x 3)", "$181.49"}
    ]
    subs = [{"Subtotal", "$198.10"}, {"Service Fee", "$17.48"}]

    # ── Dynamic sizes ──
    pad = 10
    kv_line_h = 13
    resort_header_h = 65
    price_box_h = 170
    pay_box_h = 95
    box_gap = 15
    col_gap = 5

    # ── Config — margin controls all spacing ──
    margin = %{top: 10, bottom: 10, left: 10, right: 10}
    config = %{size: :a4, margin: margin, font: "Helvetica", font_size: 10}

    # Derived: column inner width for text measurement
    page_w = 595
    col_inner_w = div(page_w - margin.left - margin.right - col_gap, 2) - pad * 2

    # ── Shared style fragments ──
    box_style = %{border: 0.8, border_color: border, border_radius: 5, padding: pad}
    kv_base = %{font_size: 10, label_color: dark, value_color: dark, value_align: :right}
    kv_style = Map.merge(kv_base, %{width: col_inner_w, line_height: kv_line_h, label_width: 0.20})

    # ── Left column: stacked alquiler boxes ──
    alq_gap = 8

    {alquiler_children, total_left_h} =
      Enum.reduce(alquileres, {[], 0}, fn alq, {acc, y_off} ->
        details = alq.details
        kv_h = Pdf.Component.KeyValue.measure_height(kv_style, details)
        box_h = resort_header_h + 2 + kv_h + pad

        box = %{type: :box, props: %{
          children: [
            %{type: :avatar, props: %{
              image: alq.image,
              style: %{position: {0, 0}, size: {75, 55}, border_radius: 5}
            }},
            %{type: :text, props: %{content: alq.name,
              style: %{position: {85, -8}, font_size: 10, bold: true, color: dark}}},
            %{type: :text, props: %{content: alq.location,
              style: %{position: {85, -20}, font_size: 9, color: gray}}},
            %{type: :text, props: %{content: alq.phone,
              style: %{position: {85, -31}, font_size: 9, color: gray}}},
            %{type: :text, props: %{content: alq.email,
              style: %{position: {85, -42}, font_size: 9, color: gray}}},
            %{type: :key_value, props: %{
              pairs: details,
              style: Map.put(kv_style, :position, {0, -(resort_header_h + 2)})
            }}
          ],
          style: Map.merge(box_style, %{position: {0, -y_off}, size: {:full, box_h}})
        }}

        {acc ++ [box], y_off + box_h + alq_gap}
      end)

    # ── Right column: Price breakdown + Payment ──
    right_h = price_box_h + box_gap + pay_box_h

    price_children = [
      %{type: :box, props: %{
        children: [
          %{type: :text, props: %{content: "Price breakdown",
            style: Map.merge(heading, %{position: {2, -6}})}},
          %{type: :key_value, props: %{
            pairs: prices,
            style: %{position: {2, -38}, width: :full, font_size: 9,
              label_color: dark, value_color: dark, line_height: 18,
              label_bold: false, value_align: :right}
          }},
          %{type: :line_segment, props: %{style: %{from: {0, -80}, to: {:full, -80}, stroke: border}}},
          %{type: :key_value, props: %{
            pairs: subs,
            style: %{position: {2, -96}, width: :full, font_size: 9,
              label_color: dark, value_color: dark, line_height: 16,
              label_bold: false, value_align: :right}
          }},
          %{type: :line_segment, props: %{style: %{from: {0, -132}, to: {:full, -132}, stroke: border}}},
          %{type: :key_value, props: %{
            pairs: [{"Total (USD)", "$215.58"}],
            style: Map.merge(kv_base, %{position: {2, -148}, width: :full, value_bold: true})
          }}
        ],
        style: Map.merge(box_style, %{position: {0, 0}, size: {:full, price_box_h}})
      }}
    ]

    payment_children = [
      %{type: :box, props: %{
        children: [
          %{type: :text, props: %{content: "Payment",
            style: Map.merge(heading, %{position: {2, -6}})}},
          %{type: :key_value, props: %{
            pairs: [{"VISA... 2060", "$215.58"}],
            style: Map.merge(kv_base, %{position: {2, -28}, width: :full,
              label_bold: false, value_bold: true})
          }},
          %{type: :text, props: %{content: "Mar 30, 2026 - 8:47:59 PM",
            style: Map.merge(small_gray, %{position: {2, -40}})}},
          %{type: :line_segment, props: %{style: %{from: {0, -49}, to: {:full, -49}, stroke: border}}},
          %{type: :key_value, props: %{
            pairs: [{"Amount paid (USD)", "$215.58"}],
            style: Map.merge(kv_base, %{position: {2, -65}, width: :full, value_bold: true})
          }}
        ],
        style: Map.merge(box_style, %{position: {0, -(price_box_h + box_gap)}, size: {:full, pay_box_h}})
      }}
    ]

    # ── Template — single two-column row, Builder auto-paginates overflow ──
    row_h = max(total_left_h, right_h)

    template = [
      %{type: :row, props: %{
        children: [
          {3, [%{type: :text, props: %{content: "Your receipt from Pine Valley RV",
            style: Map.merge(title_s, %{position: {0, -16}})}}]},
          {1, [%{type: :text, props: %{content: "PINE VALLEY",
            style: Map.merge(brand_s, %{position: {0, -16}})}}]}
        ],
        style: %{position: :cursor, size: {:full, -15}}
      }},

      %{type: :spacer, props: %{amount: 1}},

      %{type: :row, props: %{
        children: [
          {1, alquiler_children},
          {1, price_children ++ payment_children}
        ],
        style: %{position: :cursor, size: {:full, row_h}, gap: col_gap}
      }}
    ]

    Pdf.Builder.render(template, config)
  end

end
