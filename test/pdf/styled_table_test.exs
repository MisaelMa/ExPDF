defmodule Pdf.StyledTableTest do
  use Pdf.Case, async: true

  describe "styled_table/3" do
    test "renders a basic table and moves cursor down" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)

      y_before = Pdf.cursor(pdf)

      pdf =
        Pdf.styled_table(pdf, [
          ["Name", "Value"],
          ["Alpha", "100"],
          ["Beta", "200"]
        ], %{
          columns: [%{width: 200}, %{width: 100}]
        })

      y_after = Pdf.cursor(pdf)
      assert y_after < y_before
    end

    test "renders with header styling" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)
        |> Pdf.styled_table([
          ["Item", "Price"],
          ["Coffee", "$3.50"],
          ["Tea", "$2.00"]
        ], %{
          columns: [%{width: 200}, %{width: 100, align: :right}],
          header: %{bold: true, background: {0.2, 0.3, 0.5}, color: :white, padding: 8},
          row: %{padding: 6}
        })

      output = export(pdf)
      assert output =~ "Item"
      assert output =~ "Coffee"
    end

    test "renders with alternating row colors" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)
        |> Pdf.styled_table([
          ["H1", "H2"],
          ["R1", "V1"],
          ["R2", "V2"],
          ["R3", "V3"],
          ["R4", "V4"]
        ], %{
          columns: [%{width: 150}, %{width: 150}],
          header: %{bold: true, background: :navy, color: :white, padding: 8},
          row: %{padding: 6},
          alt_row: %{background: {0.95, 0.95, 1.0}}
        })

      output = export(pdf)
      assert output =~ "R1"
      assert output =~ "R4"
    end

    test "renders with border and border_radius" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)
        |> Pdf.styled_table([
          ["A", "B"],
          ["1", "2"]
        ], %{
          columns: [%{width: 100}, %{width: 100}],
          border: 1,
          border_color: :black,
          border_radius: 8
        })

      output = export(pdf)
      # rounded_rectangle uses curve_to (c operator)
      assert output =~ "c"
      assert output =~ "S"
    end

    test "renders with row bottom borders" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)
        |> Pdf.styled_table([
          ["Col1", "Col2"],
          ["A", "B"]
        ], %{
          columns: [%{width: 150}, %{width: 150}],
          row: %{padding: 6, border_bottom: 0.5, border_color: :gray}
        })

      output = export(pdf)
      assert output =~ "Col1"
    end

    test "auto-distributes column widths" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)

      y_before = Pdf.cursor(pdf)

      pdf =
        Pdf.styled_table(pdf, [
          ["Auto", "Width", "Cols"],
          ["A", "B", "C"]
        ], %{})

      assert Pdf.cursor(pdf) < y_before
    end

    test "works with footer style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 10)
        |> Pdf.styled_table([
          ["Item", "Total"],
          ["Widget", "$10"],
          ["Sum", "$10"]
        ], %{
          columns: [%{width: 200}, %{width: 100, align: :right}],
          header: %{bold: true, padding: 8},
          row: %{padding: 6},
          footer: %{bold: true, border_bottom: 0}
        })

      output = export(pdf)
      assert output =~ "Sum"
    end
  end

  describe "Builder integration" do
    test "{:table, data, opts} works in Builder" do
      template = [
        {:table, [["A", "B"], ["1", "2"]], %{
          columns: [%{width: 100}, %{width: 100}],
          row: %{padding: 6}
        }}
      ]

      doc = Pdf.Builder.render(template, %{compress: false})
      output = export(doc)
      assert output =~ "A"
      assert output =~ "1"
    end
  end
end
