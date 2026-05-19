defmodule Pdf.Component.RowTest do
  use Pdf.Case, async: true

  describe "render/5" do
    test "distributes width by weight" do
      doc = new_test_doc()

      doc =
        Pdf.Component.Row.render(doc, {50, 700}, {400, 80}, [
          {1, fn doc, area ->
            send(self(), {:col, 0, area})
            doc
          end},
          {1, fn doc, area ->
            send(self(), {:col, 1, area})
            doc
          end}
        ])

      assert_received {:col, 0, area0}
      assert_received {:col, 1, area1}

      assert area0.x == 50
      assert area0.width == 200.0
      assert area1.x == 250.0
      assert area1.width == 200.0
      assert area0.y == 700
      assert area0.height == 80
      assert %Pdf.Document{} = doc
    end

    test "distributes with different weights" do
      doc = new_test_doc()

      Pdf.Component.Row.render(doc, {0, 700}, {300, 50}, [
        {1, fn doc, area ->
          send(self(), {:col, 0, area})
          doc
        end},
        {2, fn doc, area ->
          send(self(), {:col, 1, area})
          doc
        end}
      ])

      assert_received {:col, 0, area0}
      assert_received {:col, 1, area1}

      assert area0.width == 100.0
      assert area1.width == 200.0
    end

    test "applies gap between columns" do
      doc = new_test_doc()

      Pdf.Component.Row.render(doc, {0, 700}, {210, 50}, [
        {1, fn doc, area ->
          send(self(), {:col, 0, area})
          doc
        end},
        {1, fn doc, area ->
          send(self(), {:col, 1, area})
          doc
        end}
      ], gap: 10)

      assert_received {:col, 0, area0}
      assert_received {:col, 1, area1}

      assert area0.width == 100.0
      assert area1.x == 110.0
      assert area1.width == 100.0
    end
  end

  describe "Pdf.row/5 delegate" do
    test "delegates to Component.Row" do
      doc = new_test_doc()

      doc =
        Pdf.row(doc, {50, 700}, {400, 80}, [
          {1, fn doc, _area -> doc end}
        ])

      assert %Pdf.Document{} = doc
    end
  end
end
