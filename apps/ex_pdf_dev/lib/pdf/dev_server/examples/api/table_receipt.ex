defmodule Pdf.DevServer.Examples.Api.TableReceipt do
  @moduledoc false

  def render do
    Pdf.new(size: [240, 500], margin: %{top: 30, bottom: 20, left: 15, right: 15})
    |> Pdf.set_info(title: "Receipt")
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({60, 470}, "COFFEE SHOP")
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.text_at({55, 455}, "123 Main Street")
    |> Pdf.text_at({60, 445}, "Tel: 555-0123")
    |> Pdf.set_cursor(430)
    |> Pdf.set_cursor_x(15)
    |> Pdf.horizontal_line(%{color: :black})
    |> Pdf.spacer(5)
    |> Pdf.StyledTable.render([
      ["Item", "Qty", "Total"],
      ["Cappuccino", "2", "$9.00"],
      ["Croissant", "1", "$3.50"],
      ["Green Tea", "1", "$2.50"],
      ["Muffin", "2", "$7.00"]
    ], %{
      columns: [
        %{width: 110},
        %{width: 40, align: :center},
        %{width: 60, align: :right}
      ],
      header: %{bold: true, padding: {4, 4, 4, 4}, font_size: 8, border_bottom: 1, border_color: :black},
      row: %{padding: {3, 4, 3, 4}, font_size: 9},
      font_size: 9
    })
    |> Pdf.spacer(3)
    |> Pdf.horizontal_line(%{color: :black})
    |> Pdf.spacer(5)
    |> Pdf.StyledTable.render([
      ["Subtotal", "", "$22.00"],
      ["Tax (8%)", "", "$1.76"],
      ["Total", "", "$23.76"]
    ], %{
      columns: [
        %{width: 110},
        %{width: 40},
        %{width: 60, align: :right}
      ],
      row: %{padding: {2, 4, 2, 4}, font_size: 9},
      font_size: 9
    })
    |> Pdf.spacer(10)
    |> then(fn doc ->
      y = Pdf.cursor(doc)
      doc
      |> Pdf.set_font("Helvetica", 8)
      |> Pdf.text_at({50, y}, "Thank you for your visit!")
    end)
  end
end
