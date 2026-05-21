defmodule Pdf.DevServer.Examples.Map.Receipt do
  @moduledoc """
   booking receipt using the ex_pdf declarative API.

  Visual comparison target: Core.PDF.BookingReceipt in server.

  render_with_data/1 — real data from  node via :rpc.call
  """

  # ── Public entry point ───────────────────────────────────────────────────────

  def render_with_data(%{reservations: reservations, items: items, payment: payment}) do
    reservations =
      Enum.map(reservations, fn res ->
        Map.update!(res, :details_reservation, &normalize_kv_pairs/1)
      end)

    # Keep items as groups (list of lists) so we can draw dividers between them
    price_groups =
      Enum.map(items, fn group ->
        List.flatten([group])
        |> Enum.map(fn %{concept: concept, total: total} ->
          {to_string(concept), to_string(total)}
        end)
      end)

    # Payment: last group is demibold ("Amount paid (USD)")
    last_payment_idx = length(payment) - 1

    payment_groups =
      payment
      |> Enum.with_index()
      |> Enum.map(fn {group, idx} ->
        rows =
          List.flatten([group])
          |> Enum.map(fn %{concept: concept, total: total} ->
            {to_string(concept), to_string(total)}
          end)

        {rows, idx == last_payment_idx}
      end)

    build(reservations, price_groups, payment_groups)
  end

  # ── Core layout ──────────────────────────────────────────────────────────────

  defp build(reservations, price_groups, payment_groups) do
    dark = {0.1, 0.1, 0.1}
    teal = {0.0, 0.50, 0.50}
    gray = {0.5, 0.5, 0.5}
    border = {0.82, 0.82, 0.82}
    divider_color = {0.85, 0.85, 0.85}

    margin = %{top: 10, bottom: 10, left: 10, right: 10}

    {font_r, _font_b, font_d} = avenir_fonts()

    pad = 10
    kv_line_h = 14
    alq_gap = 8
    col_gap = 5
    resort_header_h = 65
    kv_lh = 18
    kv_fs = 10
    divider_h = 8
    heading_y = 28

    page_w = 595
    col_inner_w = div(page_w - margin.left - margin.right - col_gap, 2) - pad * 2

    box_style = %{border: 0.8, border_color: border, border_radius: 5, padding: pad}
    kv_base = %{font_size: 10, label_color: dark, value_color: dark, value_align: :right}
    kv_style =
      Map.merge(kv_base, %{
        font: font_r,
        width: col_inner_w,
        line_height: kv_line_h,
        label_width: 0.27,
        label_bold: true
      })

    # ── Left column: stacked reservation cards ──────────────────────────────────
    {reservation_children, total_left_h} =
      Enum.reduce(reservations, {[], 0}, fn res, {acc, y_off} ->
        kv_h = Pdf.Component.KeyValue.measure_height(kv_style, res.details_reservation)
        box_h = resort_header_h + 2 + kv_h + 4

        cancelled_chip =
          if Map.get(res, :cancelled, false) do
            # box inner_w = col_inner_w - 2*border(0.8) - 2*padding(10)
            # chip_approx_w ≈ 58 for "CANCELLED" at fs 8, so stay ~4pt from right edge
            chip_x = col_inner_w - 65
            [%{type: :chip, props: %{
              label: "CANCELLED",
              style: %{
                position: {chip_x, 4},
                background: {0.85, 0.20, 0.20},
                color: :black,
                font_size: 8,
                height: 16,
                border_radius: 5,
                opacity: 0.4

              }
            }}]
          else
            []
          end

        box = %{
          type: :box,
          props: %{
            children: [
              %{type: :avatar, props: %{
                image: res.image,
                style: %{position: {0, 0}, size: {75, 55}, border_radius: 5}
              }},
              %{type: :text, props: %{
                content: res.details.name,
                style: %{position: {85, -8}, font_size: 10, font: font_r, bold: true, color: dark}
              }},
              %{type: :text, props: %{
                content: res.details.city,
                style: %{position: {85, -20}, font_size: 9, font: font_r, color: gray}
              }},
              %{type: :text, props: %{
                content: res.details.phone,
                style: %{position: {85, -31}, font_size: 9, font: font_r, color: gray}
              }},
              %{type: :text, props: %{
                content: res.details.support_email,
                style: %{position: {85, -42}, font_size: 9, font: font_r, color: gray}
              }},
              %{type: :key_value, props: %{
                pairs: res.details_reservation,
                style: Map.put(kv_style, :position, {0, -(resort_header_h + 2)})
              }}
              | cancelled_chip
            ],
            style: Map.merge(box_style, %{position: {0, -y_off}, size: {:full, box_h}})
          }
        }

        {acc ++ [box], y_off + box_h + alq_gap}
      end)

    # ── Right column: price breakdown + payment ─────────────────────────────────
    kv_right = %{
      font: font_r,
      width: col_inner_w,
      font_size: 10,
      label_color: dark,
      value_color: dark,
      line_height: kv_lh,
      label_bold: false,
      value_align: :right
    }

    # "Amount paid (USD)" uses the DemiBold face for visual weight
    kv_right_demibold = Map.merge(kv_right, %{font: font_d})

    # ── Build key-value groups with separator lines between them ─────────────────
    build_kv_groups = fn groups, demibold_last? ->
      Enum.reduce(groups, {[], 0}, fn item, {children, cum_h} ->
        {group, demibold?} =
          if demibold_last?,
            do: item,
            else: {item, false}

        {children, cum_h} =
          if cum_h > 0 do
            line_y = -(heading_y + cum_h - kv_lh + kv_fs + 3)
            sep = %{type: :line_segment, props: %{style: %{
              from: {0, line_y},
              to: {:full, line_y},
              stroke: divider_color,
              line_width: 0.5
            }}}
            {children ++ [sep], cum_h + divider_h}
          else
            {children, cum_h}
          end

        style = if demibold?, do: kv_right_demibold, else: kv_right
        group_h = Pdf.Component.KeyValue.measure_height(style, group)
        kv = %{type: :key_value, props: %{
          pairs: group,
          style: Map.put(style, :position, {2, -(heading_y + cum_h)})
        }}
        {children ++ [kv], cum_h + group_h}
      end)
    end

    {price_kv_children, price_kv_h} = build_kv_groups.(price_groups, false)
    {payment_kv_children, payment_kv_h} = build_kv_groups.(payment_groups, true)

    price_box_h = 30 + price_kv_h + 4
    pay_box_h = 30 + payment_kv_h + 4
    box_gap = 15

    price_box = %{
      type: :box,
      props: %{
        children: [
          %{type: :text, props: %{
            content: "Price breakdown",
            style: %{position: {2, -6}, font_size: 13, font: font_r, bold: true, color: dark}
          }}
          | price_kv_children
        ],
        style: Map.merge(box_style, %{position: {0, 0}, size: {:full, price_box_h}})
      }
    }

    payment_box = %{
      type: :box,
      props: %{
        children: [
          %{type: :text, props: %{
            content: "Payment",
            style: %{position: {2, -6}, font_size: 13, font: font_r, bold: true, color: dark}
          }}
          | payment_kv_children
        ],
        style: Map.merge(box_style, %{
          position: {0, -(price_box_h + box_gap)},
          size: {:full, pay_box_h}
        })
      }
    }

    row_h = max(total_left_h, price_box_h + box_gap + pay_box_h)

    footer_line_color = {0.8, 0.8, 0.8}

    # ── Template ─────────────────────────────────────────────────────────────────
    template = [
      %{type: :page_footer, props: %{
        height: 105,
        render: fn doc, area ->
          mb = 10
          addr_y    = mb + 10
          company_y = addr_y + 14
          label_y   = company_y + 14
          line2_y   = label_y + 10
          text_y    = line2_y + 34
          line1_y   = text_y + 8

          doc
          |> Pdf.save_state()
          |> Pdf.set_stroke_color(footer_line_color)
          |> Pdf.set_line_width(0.5)
          |> Pdf.line({area.x, line1_y}, {area.x + area.width, line1_y})
          |> Pdf.stroke()
          |> Pdf.set_font(font_r, 9)
          |> then(fn d ->
            {d, _} = Pdf.text_wrap(d, {area.x, text_y}, {area.width, 36},
              "Thank you for booking with Spot2Nite. We appreciate your business. " <>
              "If you have any questions regarding your reservation, please call us at " <>
              "1-877-778-2683 (Ext 1) or email us at support@spot2nite.com",
              [font_size: 9, color: dark])
            d
          end)
          |> Pdf.set_stroke_color(footer_line_color)
          |> Pdf.set_line_width(0.5)
          |> Pdf.line({area.x, line2_y}, {area.x + area.width, line2_y})
          |> Pdf.stroke()
          |> Pdf.text_at({area.x, label_y}, "Payment processed by:", %{font: font_r, font_size: 10, bold: true, color: dark})
          |> Pdf.text_at({area.x, company_y}, "Spot2Nite, Inc", %{font: font_r, font_size: 10, color: dark})
          |> Pdf.text_at({area.x, addr_y}, "PO Box 15372, New Orleans, LA 70175", %{font: font_r, font_size: 10, color: dark})
          |> Pdf.restore_state()
        end
      }},

      %{type: :row, props: %{
        children: [
          {3, [%{type: :text, props: %{
            content: "Your receipt from Spot2Nite",
            style: %{position: {0, -16}, font_size: 17, font: font_r, bold: true, color: dark}
          }}]},
          {1, [%{type: :text, props: %{
            content: "SPOT2NITE",
            style: %{position: {0, -16}, font_size: 14, font: font_r, bold: true, color: teal}
          }}]}
        ],
        style: %{position: :cursor, size: {:full, -15}}
      }},

      %{type: :spacer, props: %{amount: 25}},

      %{type: :row, props: %{
        children: [
          {1, reservation_children},
          {1, [price_box, payment_box]}
        ],
        style: %{position: :cursor, size: {:full, row_h}, gap: col_gap}
      }},

    ]

    doc = new_doc(margin)
    Pdf.Builder.render_into(doc, template)
  end

  # ── Font helpers ──────────────────────────────────────────────────────────────

  defp avenir_fonts do
    case Application.get_env(:ex_pdf_dev, :fonts_dir) do
      nil -> {"Helvetica", "Helvetica", "Helvetica"}
      _ -> {"AvenirNext-Regular", "AvenirNext-Bold", "AvenirNext-DemiBold"}
    end
  end

  defp new_doc(margin) do
    doc = Pdf.new(size: :a4, margin: margin, compress: false)

    case Application.get_env(:ex_pdf_dev, :fonts_dir) do
      nil ->
        Pdf.set_font(doc, "Helvetica", 10)

      fonts_dir ->
        doc
        |> Pdf.add_font(Path.join(fonts_dir, "AvenirNext-Regular.afm"))
        |> Pdf.add_font(Path.join(fonts_dir, "AvenirNext-Bold.afm"))
        |> Pdf.add_font(Path.join(fonts_dir, "AvenirNext-DemiBold.afm"))
        |> Pdf.set_font("AvenirNext-Regular", 10)
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp normalize_kv_pairs(pairs) when is_list(pairs) do
    Enum.map(pairs, fn
      {label, value} when is_list(value) ->
        {to_string(label), Enum.map(value, &normalize_rich_segment/1)}

      {label, value} ->
        {to_string(label), stringify_kv_value(value)}
    end)
  end

  defp normalize_rich_segment(%{text: text} = seg),
    do: Map.put(seg, :text, stringify_kv_value(text))

  defp normalize_rich_segment(seg), do: seg

  defp stringify_kv_value(nil), do: ""
  defp stringify_kv_value(value) when is_binary(value), do: value
  defp stringify_kv_value(value), do: to_string(value)
end
