defmodule Pdf.Component.CardTest do
  use Pdf.Case, async: true

  describe "render/5" do
    test "renders a basic card with callback" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(doc, {50, 700}, {300, 150}, %{}, fn doc, area ->
          Pdf.text_at(doc, {area.x, area.y - 14}, "Card content")
        end)

      output = export(doc)
      assert output =~ "Card content"
    end

    test "renders with elevation shadow" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(doc, {50, 700}, {300, 150}, %{elevation: 3}, fn doc, _area ->
          doc
        end)

      output = export(doc)
      # Shadow uses black fill with opacity
      assert output =~ "0.0 0.0 0.0 rg"
      assert output =~ "gs"
    end

    test "renders with no elevation (no shadow)" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(doc, {50, 700}, {300, 150}, %{elevation: 0}, fn doc, _area ->
          doc
        end)

      assert export(doc)
    end

    test "renders with border" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(
          doc,
          {50, 700},
          {300, 150},
          %{border: 1, border_color: {0.8, 0.8, 0.8}},
          fn doc, _area -> doc end
        )

      output = export(doc)
      assert output =~ "0.8 0.8 0.8 RG"
    end

    test "renders with header" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(
          doc,
          {50, 700},
          {300, 200},
          %{header: %{title: "My Card", subtitle: "Subtitle here"}},
          fn doc, area ->
            Pdf.text_at(doc, {area.x, area.y - 14}, "Body")
          end
        )

      output = export(doc)
      assert output =~ "My Card"
      assert output =~ "Subtitle here"
      assert output =~ "Body"
    end

    test "renders with footer" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(
          doc,
          {50, 700},
          {300, 200},
          %{footer: %{text: "Footer info"}},
          fn doc, _area -> doc end
        )

      output = export(doc)
      assert output =~ "Footer info"
    end

    test "renders without callback" do
      doc = new_test_doc()
      doc = Pdf.Component.Card.render(doc, {50, 700}, {300, 150}, %{elevation: 2})
      assert export(doc)
    end

    test "content area accounts for header and padding" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Card.render(
          doc,
          {50, 700},
          {300, 200},
          %{header: %{title: "T", height: 40}, padding: 10},
          fn doc, area ->
            # area.y should be below header + padding
            assert area.y == 700 - 40 - 10
            assert area.x == 50 + 10
            assert area.width == 300 - 20
            doc
          end
        )

      assert export(doc)
    end

    test "renders via Builder with children" do
      template = [
        %{
          card: {50, 700},
          size: {300, 150},
          elevation: 2,
          border_radius: 10,
          children: [
            %{text: "Inside card", x: 0, y: -14, bold: true}
          ]
        }
      ]

      doc = Pdf.Builder.render(template, %{size: :a4, font: "Helvetica", font_size: 12, compress: false})
      output = export(doc)
      assert output =~ "Inside card"
    end
  end
end
