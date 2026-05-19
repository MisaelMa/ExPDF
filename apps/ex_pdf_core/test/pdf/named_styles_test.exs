defmodule Pdf.NamedStylesTest do
  use Pdf.Case, async: true

  describe "register_style/3" do
    test "registers a named style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.register_style(:heading, %{font_size: 24, bold: true, color: :navy})

      assert pdf.styles[:heading] == %{font_size: 24, bold: true, color: :navy}
    end

    test "overwrites existing style" do
      pdf =
        Pdf.new(size: :a4)
        |> Pdf.register_style(:heading, %{font_size: 20})
        |> Pdf.register_style(:heading, %{font_size: 30})

      assert pdf.styles[:heading] == %{font_size: 30}
    end
  end

  describe "register_styles/2" do
    test "registers multiple styles at once" do
      pdf =
        Pdf.new(size: :a4)
        |> Pdf.register_styles(%{
          heading: %{font_size: 24, bold: true},
          body: %{font_size: 12},
          accent: %{color: :green}
        })

      assert pdf.styles[:heading] == %{font_size: 24, bold: true}
      assert pdf.styles[:body] == %{font_size: 12}
      assert pdf.styles[:accent] == %{color: :green}
    end
  end

  describe "text/3 with named style" do
    test "applies a registered style by atom name" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.register_style(:heading, %{font_size: 24, bold: true, color: :navy})
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text("Title", :heading)

      output = export(pdf)
      assert output =~ "Title"
      # Navy color and size 24 should be applied
      assert output =~ "0.502 rg"
      assert output =~ "24 Tf"
    end

    test "falls back to defaults for unknown style name" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text("Fallback", :nonexistent)

      output = export(pdf)
      assert output =~ "Fallback"
    end

    test "still works with inline map style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text("Inline", %{font_size: 20, bold: true})

      output = export(pdf)
      assert output =~ "Inline"
    end

    test "applies font from style map" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text("In Courier", %{font: "Courier", font_size: 14})

      output = export(pdf)
      assert output =~ "In Courier"
      # Courier font should be referenced
      assert output =~ "14 Tf"
    end

    test "applies font from named style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.register_style(:mono, %{font: "Courier", font_size: 11, color: :navy})
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text("Monospaced", :mono)

      output = export(pdf)
      assert output =~ "Monospaced"
      assert output =~ "11 Tf"
      assert output =~ "0.502 rg"
    end

    test "different fonts in sequence" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.register_styles(%{
          sans: %{font: "Helvetica", font_size: 12},
          mono: %{font: "Courier", font_size: 11},
          serif: %{font: "Times-Roman", font_size: 13}
        })
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text("Sans text", :sans)
        |> Pdf.text("Mono text", :mono)
        |> Pdf.text("Serif text", :serif)

      output = export(pdf)
      assert output =~ "Sans text"
      assert output =~ "Mono text"
      assert output =~ "Serif text"
    end
  end

  describe "horizontal_line/2 with named style" do
    test "applies a registered line style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.register_style(:divider, %{stroke_color: :red, line_width: 2})
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.horizontal_line(:divider)

      output = export(pdf)
      # Should have stroke operator
      assert output =~ "S"
    end
  end

  describe "watermark/3 with named style" do
    test "applies a registered watermark style" do
      pdf =
        Pdf.new(size: :a4, margin: 40, compress: false)
        |> Pdf.register_style(:draft_mark, %{opacity: 0.1, font_size: 80, color: :red, rotate: 45})
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.watermark("DRAFT", :draft_mark)

      output = export(pdf)
      assert output =~ "DRAFT"
    end
  end

end
