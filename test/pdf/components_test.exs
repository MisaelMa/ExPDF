defmodule Pdf.ComponentsTest do
  use Pdf.Case, async: true

  describe "text/2,3" do
    test "writes text and moves cursor down" do
      pdf =
        Pdf.new(size: :a4, margin: 40)
        |> Pdf.set_font("Helvetica", 12)

      y_before = Pdf.cursor(pdf)

      pdf = Pdf.text(pdf, "Hello world")

      y_after = Pdf.cursor(pdf)
      assert y_after < y_before
    end

    test "applies style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.text("Bold text", %{bold: true, font_size: 16})

      output = export(pdf.current)
      assert output =~ "Bold text"
    end
  end

  describe "horizontal_line/1,2" do
    test "draws a line and moves cursor" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 12)

      y_before = Pdf.cursor(pdf)
      pdf = Pdf.horizontal_line(pdf)
      y_after = Pdf.cursor(pdf)

      assert y_after < y_before
      output = export(pdf.current)
      assert output =~ "S"
    end
  end

  describe "spacer/2" do
    test "moves cursor down by amount" do
      pdf = Pdf.new(size: :a4, margin: 40)
      y_before = Pdf.cursor(pdf)

      pdf = Pdf.spacer(pdf, 25)

      assert Pdf.cursor(pdf) == y_before - 25
    end
  end

  describe "page_break/1" do
    test "adds a new page" do
      pdf = Pdf.new(size: :a4)
      assert Pdf.page_number(pdf) == 1

      pdf = Pdf.page_break(pdf)
      assert Pdf.page_number(pdf) == 2
    end

    test "resets cursor to top of content area" do
      pdf = Pdf.new(size: :a4, margin: 50)
      %{height: ph} = Pdf.size(pdf)
      expected_y = ph - 50

      pdf = pdf |> Pdf.spacer(200) |> Pdf.page_break()
      assert Pdf.cursor(pdf) == expected_y
    end
  end

  describe "watermark/2,3" do
    test "adds watermark with opacity and rotation" do
      pdf =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.watermark("DRAFT")

      output = export(pdf.current)
      assert output =~ "gs"
      assert output =~ "cm"
      assert output =~ "DRAFT"
      assert output =~ "q"
      assert output =~ "Q"
    end

    test "accepts custom style" do
      pdf =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.watermark("CONFIDENTIAL", %{opacity: 0.3, rotate: 30, font_size: 72})

      output = export(pdf.current)
      assert output =~ "CONFIDENTIAL"
    end
  end

  describe "background/2" do
    test "fills page with background color" do
      pdf =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.background(%{background: :blue})

      output = export(pdf.current)
      assert output =~ "0.0 0.0 1.0 rg"
      assert output =~ "re"
      assert output =~ "f"
    end

    test "does nothing without background color" do
      pdf =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.background(%{})

      output = export(pdf.current)
      assert output == "\n"
    end
  end
end
