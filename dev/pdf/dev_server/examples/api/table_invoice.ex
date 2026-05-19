defmodule Pdf.DevServer.Examples.Api.TableInvoice do
  @moduledoc false

  def render do
    Pdf.new(size: :a4, margin: %{top: 50, bottom: 50, left: 50, right: 50})
    |> Pdf.set_info(title: "Invoice")
    # Header
    |> Pdf.set_font("Helvetica", 28)
    |> Pdf.set_fill_color({0.15, 0.23, 0.38})
    |> Pdf.text_at({50, 780}, "INVOICE")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({400, 785}, "Invoice #: INV-2026-001")
    |> Pdf.text_at({400, 772}, "Date: April 1, 2026")
    |> Pdf.text_at({400, 759}, "Due: April 30, 2026")
    # From / To
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({50, 730}, "FROM")
    |> Pdf.text_at({300, 730}, "BILL TO", %{bold: true})
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({50, 716}, "Acme Corp")
    |> Pdf.text_at({50, 703}, "456 Business Ave")
    |> Pdf.text_at({50, 690}, "contact@acme.com")
    |> Pdf.text_at({300, 716}, "Client Industries")
    |> Pdf.text_at({300, 703}, "789 Client Blvd")
    |> Pdf.text_at({300, 690}, "billing@client.com")
    # Line separator
    |> Pdf.save_state()
    |> Pdf.set_stroke_color({0.15, 0.23, 0.38})
    |> Pdf.set_line_width(2)
    |> Pdf.line({50, 675}, {545, 675})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    # Items table
    |> Pdf.set_cursor(665)
    |> Pdf.set_cursor_x(50)
    |> Pdf.spacer(5)
    |> Pdf.styled_table(items_data(), items_style())
    # Totals
    |> Pdf.spacer(15)
    |> Pdf.styled_table(totals_data(), totals_style())
    # Footer note
    |> Pdf.spacer(30)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> (fn doc ->
      pos = Pdf.cursor_xy(doc)
      doc
      |> Pdf.text_at({50, pos.y}, "Payment Terms: Net 30 days")
      |> Pdf.text_at({50, pos.y - 14}, "Please make checks payable to Acme Corp")
      |> Pdf.text_at({50, pos.y - 28}, "Thank you for your business!")
    end).()
    # Page 2: same invoice with debug grid (area: :page)
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{area: :page, spacing: 10, color: {0.9, 0.9, 0.9}})
    |> render_invoice_body()
    # Page 3: same invoice with debug grid (area: :content)
    |> Pdf.page_break()
    |> Pdf.debug_grid(%{area: :content, spacing: 10, color: {0.9, 0.9, 0.9}})
    |> render_invoice_body()
  end

  defp render_invoice_body(doc) do
    doc
    |> Pdf.set_font("Helvetica", 28)
    |> Pdf.set_fill_color({0.15, 0.23, 0.38})
    |> Pdf.text_at({50, 780}, "INVOICE")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({400, 785}, "Invoice #: INV-2026-001")
    |> Pdf.text_at({400, 772}, "Date: April 1, 2026")
    |> Pdf.text_at({400, 759}, "Due: April 30, 2026")
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> Pdf.text_at({50, 730}, "FROM")
    |> Pdf.text_at({300, 730}, "BILL TO")
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({50, 716}, "Acme Corp")
    |> Pdf.text_at({50, 703}, "456 Business Ave")
    |> Pdf.text_at({50, 690}, "contact@acme.com")
    |> Pdf.text_at({300, 716}, "Client Industries")
    |> Pdf.text_at({300, 703}, "789 Client Blvd")
    |> Pdf.text_at({300, 690}, "billing@client.com")
    |> Pdf.save_state()
    |> Pdf.set_stroke_color({0.15, 0.23, 0.38})
    |> Pdf.set_line_width(2)
    |> Pdf.line({50, 675}, {545, 675})
    |> Pdf.stroke()
    |> Pdf.restore_state()
    |> Pdf.set_cursor(665)
    |> Pdf.set_cursor_x(50)
    |> Pdf.spacer(5)
    |> Pdf.styled_table(items_data(), items_style())
    |> Pdf.spacer(15)
    |> Pdf.styled_table(totals_data(), totals_style())
    |> Pdf.spacer(30)
    |> Pdf.set_font("Helvetica", 9)
    |> Pdf.set_fill_color(:gray)
    |> (fn doc ->
      pos = Pdf.cursor_xy(doc)
      doc
      |> Pdf.text_at({50, pos.y}, "Payment Terms: Net 30 days")
      |> Pdf.text_at({50, pos.y - 14}, "Please make checks payable to Acme Corp")
      |> Pdf.text_at({50, pos.y - 28}, "Thank you for your business!")
    end).()
  end

  defp items_data do
    [
      ["Description", "Hours", "Rate", "Amount"],
      ["Web Application Development", "40", "$120.00", "$4,800.00"],
      ["API Integration", "16", "$120.00", "$1,920.00"],
      ["Database Design", "8", "$135.00", "$1,080.00"],
      ["Code Review & QA", "12", "$100.00", "$1,200.00"],
      ["Documentation", "6", "$90.00", "$540.00"]
    ]
  end

  defp items_style do
    %{
      columns: [
        %{width: 220},
        %{width: 60, align: :center},
        %{width: 90, align: :right},
        %{width: 125, align: :right}
      ],
      header: %{bold: true, background: {0.15, 0.23, 0.38}, color: :white, padding: 10, font_size: 10},
      row: %{padding: 8, border_bottom: 0.5, border_color: {0.88, 0.88, 0.88}, font_size: 10},
      alt_row: %{background: {0.96, 0.97, 1.0}},
      border: 1,
      border_color: {0.15, 0.23, 0.38},
      border_radius: 4
    }
  end

  defp totals_data do
    [
      ["Subtotal", "$9,540.00"],
      ["Tax (10%)", "$954.00"],
      ["Total Due", "$10,494.00"]
    ]
  end

  defp totals_style do
    %{
      columns: [
        %{width: 365, align: :right},
        %{width: 130, align: :right}
      ],
      row: %{padding: 6, font_size: 10, border_bottom: 0.3, border_color: {0.85, 0.85, 0.85}},
      font_size: 10
    }
  end
end
