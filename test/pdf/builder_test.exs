defmodule Pdf.BuilderTest do
  use Pdf.Case, async: true

  alias Pdf.Builder

  describe "render/2" do
    test "renders a simple text template" do
      template = [
        {:text, "Hello World"}
      ]

      doc = Builder.render(template, %{size: :a4, margin: 40, compress: false})
      output = export(doc.current)
      assert output =~ "Hello World"
    end

    test "renders text with style" do
      template = [
        {:text, "Big Title", %{font_size: 24, bold: true}}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Big Title"
    end

    test "renders spacer" do
      template = [
        {:spacer, 50}
      ]

      config = %{size: :a4, margin: 40}
      doc = Builder.render(template, config)
      %{height: ph} = Pdf.size(doc)
      expected_y = ph - 40 - 50

      assert Pdf.cursor(doc) == expected_y
    end

    test "renders horizontal line" do
      template = [
        {:line}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "S"
    end

    test "renders line with style" do
      template = [
        {:line, %{color: :red}}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "S"
    end

    test "renders page break" do
      template = [
        {:text, "Page 1"},
        {:page_break},
        {:text, "Page 2"}
      ]

      doc = Builder.render(template, %{compress: false})
      assert Pdf.page_number(doc) == 2
    end

    test "renders watermark" do
      template = [
        {:watermark, "DRAFT", %{opacity: 0.1}}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "DRAFT"
    end

    test "renders background" do
      template = [
        {:background, %{background: :blue}}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "0.0 0.0 1.0 rg"
    end

    test "applies default config" do
      doc = Builder.render([], %{})
      assert Pdf.page_number(doc) == 1
    end

    test "registers header template from config" do
      test_pid = self()

      config = %{
        header: fn doc, info ->
          send(test_pid, {:header, info.number})
          doc
        end
      }

      _doc =
        Builder.render([{:page_break}], config)

      assert_receive {:header, 2}
    end

    test "registers footer template from config" do
      test_pid = self()

      config = %{
        footer: fn doc, info ->
          send(test_pid, {:footer, info.number})
          doc
        end
      }

      _doc = Builder.render([{:page_break}], config)

      assert_receive {:footer, 1}
    end

    test "renders a complex multi-element template" do
      template = [
        {:text, "Title", %{font_size: 24, bold: true}},
        {:spacer, 10},
        {:text, "Subtitle", %{font_size: 14, color: :gray}},
        {:line, %{color: :gray}},
        {:spacer, 5},
        {:text, "Body content goes here"},
        {:page_break},
        {:text, "Page 2 content"}
      ]

      config = %{
        size: :a4,
        margin: %{top: 60, bottom: 60, left: 40, right: 40},
        font: "Helvetica",
        font_size: 12,
        compress: false
      }

      doc = Builder.render(template, config)
      assert Pdf.page_number(doc) == 2
    end
  end

  describe "render_into/2" do
    test "renders elements into existing document" do
      doc =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.set_font("Helvetica", 12)

      doc = Builder.render_into(doc, [
        {:text, "Added via render_into"},
        {:spacer, 10}
      ])

      output = export(doc.current)
      assert output =~ "Added via render_into"
    end
  end
end
