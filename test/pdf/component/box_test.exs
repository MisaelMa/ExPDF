defmodule Pdf.Component.BoxTest do
  use Pdf.Case, async: true

  describe "render/5" do
    test "renders a box and calls callback with inner area" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{}, fn doc, area ->
          assert area.x == 50
          assert area.y == 700
          assert area.width == 200
          assert area.height == 100
          doc
        end)

      assert %Pdf.Document{} = doc
    end

    test "applies padding to inner area" do
      doc = new_test_doc()

      Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{padding: 10}, fn doc, area ->
        assert area.x == 60
        assert area.y == 690
        assert area.width == 180
        assert area.height == 80
        doc
      end)
    end

    test "applies margin to outer area and inner area" do
      doc = new_test_doc()

      Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{margin: 5}, fn doc, area ->
        assert area.x == 55
        assert area.y == 695
        assert area.width == 190
        assert area.height == 90
        doc
      end)
    end

    test "applies border to inner area" do
      doc = new_test_doc()

      Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{border: 2}, fn doc, area ->
        assert area.x == 52
        assert area.y == 698
        assert area.width == 196
        assert area.height == 96
        doc
      end)
    end

    test "draws background" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{background: {0.9, 0.9, 1.0}}, fn doc, _area ->
          doc
        end)

      output = export(doc)
      assert output =~ "0.9 0.9 1.0 rg"
      assert output =~ "re"
      assert output =~ "f"
    end

    test "draws border with stroke" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{border: 1, border_color: :red}, fn doc, _area ->
          doc
        end)

      output = export(doc)
      assert output =~ "1.0 0.0 0.0 RG"
      assert output =~ "re"
      assert output =~ "S"
    end

    test "draws rounded rectangle when border_radius > 0" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Box.render(doc, {50, 700}, {200, 100}, %{border: 1, border_radius: 10}, fn doc, _area ->
          doc
        end)

      output = export(doc)
      # Rounded rectangles use bezier curves (c operator)
      assert output =~ "c"
      assert output =~ "S"
    end

    test "combines padding, margin, and border" do
      doc = new_test_doc()

      Pdf.Component.Box.render(
        doc,
        {50, 700},
        {300, 200},
        %{margin: 10, padding: 15, border: 2},
        fn doc, area ->
          # outer: x=60, y=690, w=280, h=180
          # inner: x=60+2+15=77, y=690-2-15=673, w=280-4-30=246, h=180-4-30=146
          assert area.x == 77
          assert area.y == 673
          assert area.width == 246
          assert area.height == 146
          doc
        end
      )
    end
  end

  describe "Pdf.box/5 delegate" do
    test "delegates to Component.Box" do
      doc = new_test_doc()

      doc =
        Pdf.box(doc, {50, 700}, {200, 100}, %{padding: 10}, fn doc, area ->
          assert area.width == 180
          doc
        end)

      assert %Pdf.Document{} = doc
    end

    test "resolves :full width against document content area" do
      doc = Pdf.new(size: :a4, margin: 50, compress: false)
      content = Pdf.content_area(doc)

      Pdf.box(doc, {50, 700}, {:full, 100}, fn doc, area ->
        assert area.width == content.width
        assert area.height == 100
        doc
      end)
    end

    test "resolves percentage width against document content area" do
      doc = Pdf.new(size: :a4, margin: 50, compress: false)
      content = Pdf.content_area(doc)

      Pdf.box(doc, {50, 700}, {"50%", 100}, fn doc, area ->
        assert area.width == content.width * 0.5
        doc
      end)
    end

    test "resolves {:full, :full} against document content area" do
      doc = Pdf.new(size: :a4, margin: 50, compress: false)
      content = Pdf.content_area(doc)

      Pdf.box(doc, {50, 700}, {:full, :full}, fn doc, area ->
        assert area.width == content.width
        assert area.height == content.height
        doc
      end)
    end

    test "absolute size still works unchanged" do
      doc = new_test_doc()

      Pdf.box(doc, {50, 700}, {300, 200}, fn doc, area ->
        assert area.width == 300
        assert area.height == 200
        doc
      end)
    end
  end
end
