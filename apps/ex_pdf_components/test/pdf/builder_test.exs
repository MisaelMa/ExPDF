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

  describe "map-based box component" do
    test "renders box with children" do
      template = [
        %{box: {50, 700}, size: {200, 100}, border: 1, children: [
          %{text: "Inside box", x: 5, y: -14}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Inside box"
      assert output =~ "re"
      assert output =~ "S"
    end

    test "children use relative positioning by default" do
      template = [
        %{box: {100, 500}, size: {200, 100}, padding: 10, children: [
          %{text: "Relative", x: 0, y: -14}
        ]}
      ]

      # Should compile and render without error
      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Relative"
    end

    test "children with position: :absolute use page coordinates" do
      template = [
        %{box: {100, 500}, size: {200, 100}, padding: 10, children: [
          %{text: "Absolute", x: 300, y: 800, position: :absolute}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Absolute"
    end

    test "box with background and border_radius" do
      template = [
        %{box: {50, 700}, size: {200, 100}, background: {0.9, 0.9, 1.0}, border_radius: 10, children: [
          %{text: "Rounded", x: 5, y: -14}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "0.9 0.9 1.0 rg"
      assert output =~ "c"
      assert output =~ "Rounded"
    end

    test "nested boxes" do
      template = [
        %{box: {50, 700}, size: {300, 200}, padding: 10, children: [
          %{box: {0, 0}, size: {100, 50}, border: 1, children: [
            %{text: "Nested", x: 5, y: -14}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Nested"
    end
  end

  describe "map-based row component" do
    test "renders row with children" do
      template = [
        %{row: {50, 700}, size: {400, 80}, children: [
          {1, [%{text: "Col 1", x: 5, y: -14}]},
          {1, [%{text: "Col 2", x: 5, y: -14}]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Col 1"
      assert output =~ "Col 2"
    end

    test "row with gap" do
      template = [
        %{row: {50, 700}, size: {400, 80}, gap: 10, children: [
          {1, [%{text: "Left", x: 0, y: -14}]},
          {1, [%{text: "Right", x: 0, y: -14}]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Left"
      assert output =~ "Right"
    end
  end

  describe "map-based column component" do
    test "renders column with children" do
      template = [
        %{column: {50, 700}, size: {300, 200}, children: [
          {50, [%{text: "Row 1", x: 5, y: -14}]},
          {50, [%{text: "Row 2", x: 5, y: -14}]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Row 1"
      assert output =~ "Row 2"
    end

    test "column with gap" do
      template = [
        %{column: {50, 700}, size: {300, 200}, gap: 10, children: [
          {40, [%{text: "First", x: 0, y: -14}]},
          {40, [%{text: "Second", x: 0, y: -14}]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "First"
      assert output =~ "Second"
    end
  end

  describe "relative sizing" do
    test "box with size: {:full, N} takes parent width" do
      template = [
        %{box: {50, 700}, size: {300, 200}, padding: 10, children: [
          %{box: {0, 0}, size: {:full, 50}, border: 1, children: [
            %{text: "Full width child", x: 5, y: -14}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Full width child"
    end

    test "box with percentage width" do
      template = [
        %{box: {50, 700}, size: {400, 200}, padding: 0, children: [
          %{box: {0, 0}, size: {"50%", 50}, border: 1, children: [
            %{text: "Half width", x: 5, y: -14}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Half width"
    end

    test "box with percentage height" do
      template = [
        %{box: {50, 700}, size: {300, 200}, padding: 0, children: [
          %{box: {0, 0}, size: {100, "50%"}, border: 1, children: [
            %{text: "Half height", x: 5, y: -14}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Half height"
    end

    test "box with {:full, :full} takes both dimensions from parent" do
      template = [
        %{box: {50, 700}, size: {300, 200}, padding: 10, children: [
          %{box: {0, 0}, size: {:full, :full}, background: {0.9, 0.9, 1.0}, children: [
            %{text: "Fills parent", x: 5, y: -14}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Fills parent"
    end

    test "box with {\"100%\", \"100%\"} is equivalent to {:full, :full}" do
      template = [
        %{box: {50, 700}, size: {300, 200}, padding: 0, children: [
          %{box: {0, 0}, size: {"100%", "100%"}, border: 1, children: [
            %{text: "Full pct", x: 5, y: -14}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Full pct"
    end

    test "nested boxes with relative sizing" do
      template = [
        %{box: {50, 700}, size: {400, 300}, padding: 10, children: [
          %{box: {0, 0}, size: {:full, 100}, padding: 5, border: 1, children: [
            %{box: {0, 0}, size: {"50%", :full}, background: {1.0, 0.9, 0.9}, children: [
              %{text: "Deep nested", x: 5, y: -14}
            ]}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Deep nested"
    end

    test "row with :full width inside box resolves before render" do
      template = [
        %{box: {50, 700}, size: {200, :auto}, padding: 5, border: 1, children: [
          %{type: :row, props: %{
            style: %{size: {:full, :auto}, gap: 10},
            children: [
              {0, [%{type: :text, props: %{content: "Left", style: %{font_size: 10}}}]},
              {1, [%{type: :text, props: %{content: "Right side text", style: %{font_size: 10}}}]}
            ]
          }}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Left"
      assert output =~ "Right side"
    end

    test "box with stack flows text without fixed y positions" do
      long_text =
        "Very Long Resort Name That Should Wrap And Push The Next Line Down Below Tampa"

      template = [
        %{box: {50, 700}, size: {180, :auto}, padding: 5, border: 1, children: [
          %{stack: {10, -8}, gap: 0, children: [
            %{text: long_text, font_size: 10, bold: true},
            %{text: "Tampa, FL", font_size: 9}
          ]}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Tampa, FL"
      assert output =~ "Very Long Resort"
    end

    test "box with layout :flow wraps long text and grows with :auto height" do
      long_text =
        "This is a very long line of text that should wrap inside the box and push the next element down below it."

      template = [
        %{box: {50, 700}, size: {150, :auto}, layout: :flow, gap: 4, padding: 5, border: 1, children: [
          %{text: long_text, font_size: 10},
          %{text: "Second line", font_size: 10}
        ]}
      ]

      height =
        Builder.measure_box_height(
          %{layout: :flow, gap: 4, padding: 5, border: 1},
          [
            %{text: long_text, font_size: 10},
            %{text: "Second line", font_size: 10}
          ],
          150
        )

      assert height > 40

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Second line"
      assert output =~ "wrap inside the box"
    end

    test "box with reflow wraps text and pushes content below anchor" do
      long_name =
        "Very Long Resort Name That Should Wrap And Push The Date Strip Down Below The Header"

      template = [
        %{box: {50, 700}, size: {150, :auto}, reflow: true, reflow_anchor: 40, padding: 5, border: 1, children: [
          %{text: long_name, x: 0, y: -5, font_size: 10},
          %{text: "Below anchor", x: 0, y: -45, font_size: 10}
        ]}
      ]

      height =
        Builder.measure_box_height_absolute(
          %{reflow: true, reflow_anchor: 40, padding: 5, border: 1},
          [
            %{text: long_name, x: 0, y: -5, font_size: 10},
            %{text: "Below anchor", x: 0, y: -45, font_size: 10}
          ],
          150
        )

      assert height > 55

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Below anchor"
      assert output =~ "Resort Name"
    end

    test "top-level box ignores relative sizing (no parent)" do
      template = [
        %{box: {50, 700}, size: {300, 200}, border: 1, children: [
          %{text: "Top level", x: 5, y: -14}
        ]}
      ]

      doc = Builder.render(template, %{compress: false})
      output = export(doc.current)
      assert output =~ "Top level"
    end
  end

  describe "render_into/2" do
    test "renders elements into existing document" do
      doc =
        Pdf.new(size: :a4, compress: false)
        |> Pdf.set_font("Helvetica", 12)

      doc =
        Builder.render_into(doc, [
          {:text, "Added via render_into"},
          {:spacer, 10}
        ])

      output = export(doc.current)
      assert output =~ "Added via render_into"
    end
  end
end
