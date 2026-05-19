defmodule Pdf.Component.ColumnTest do
  use Pdf.Case, async: true

  describe "render/5" do
    test "stacks rows vertically" do
      doc = new_test_doc()

      Pdf.Component.Column.render(doc, {50, 700}, {300, 200}, [
        {50, fn doc, area ->
          send(self(), {:row, 0, area})
          doc
        end},
        {80, fn doc, area ->
          send(self(), {:row, 1, area})
          doc
        end}
      ])

      assert_received {:row, 0, area0}
      assert_received {:row, 1, area1}

      assert area0.x == 50
      assert area0.y == 700
      assert area0.width == 300
      assert area0.height == 50

      assert area1.x == 50
      assert area1.y == 650
      assert area1.width == 300
      assert area1.height == 80
    end

    test "applies gap between rows" do
      doc = new_test_doc()

      Pdf.Component.Column.render(doc, {50, 700}, {300, 200}, [
        {40, fn doc, area ->
          send(self(), {:row, 0, area})
          doc
        end},
        {40, fn doc, area ->
          send(self(), {:row, 1, area})
          doc
        end}
      ], gap: 10)

      assert_received {:row, 0, area0}
      assert_received {:row, 1, area1}

      assert area0.y == 700
      assert area1.y == 650
    end
  end

  describe "Pdf.column/5 delegate" do
    test "delegates to Component.Column" do
      doc = new_test_doc()

      doc =
        Pdf.column(doc, {50, 700}, {300, 200}, [
          {50, fn doc, _area -> doc end}
        ])

      assert %Pdf.Document{} = doc
    end
  end
end
