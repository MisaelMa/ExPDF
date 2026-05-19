defmodule Pdf.LayoutTest do
  use Pdf.Case, async: true

  alias Pdf.{Page, Layout, Fonts, ObjectCollection}

  setup do
    objects = ObjectCollection.new()
    fonts = Fonts.new()
    page = Page.new(size: :a4, fonts: fonts, objects: objects, compress: false)
    {font, fonts, objects} = Fonts.get_font(fonts, objects, "Helvetica", [])
    page = %{page | fonts: fonts, objects: objects, current_font: font, current_font_size: 12}
    {:ok, page: page}
  end

  describe "box/5" do
    test "passes inner content area to callback", %{page: page} do
      {_page, area} =
        Layout.box(page, {50, 700}, {200, 100}, [style: %{padding: 10}], fn page, area ->
          {page, area}
        end)

      assert area.x == 60
      assert area.y == 690
      assert area.width == 180
      assert area.height == 80
    end

    test "applies margin", %{page: page} do
      {_page, area} =
        Layout.box(page, {50, 700}, {200, 100}, [style: %{margin: 5, padding: 0}], fn page,
                                                                                      area ->
          {page, area}
        end)

      assert area.x == 55
      assert area.y == 695
      assert area.width == 190
      assert area.height == 90
    end

    test "draws background when specified", %{page: page} do
      page =
        Layout.box(page, {50, 700}, {200, 100}, [style: %{background: :blue}], fn page, _area ->
          page
        end)

      output = export(page)
      assert output =~ "0.0 0.0 1.0 rg"
      assert output =~ "re"
      assert output =~ "f"
    end

    test "draws borders when specified", %{page: page} do
      page =
        Layout.box(page, {50, 700}, {200, 100}, [style: %{border: 1}], fn page, _area ->
          page
        end)

      output = export(page)
      assert output =~ "S"
    end
  end

  describe "row/5" do
    test "distributes width by weight", %{page: page} do
      _page =
        Layout.row(page, {0, 700}, {300, 50}, [
          {1,
           fn page, area ->
             send(self(), {:area, area})
             page
           end},
          {2,
           fn page, area ->
             send(self(), {:area, area})
             page
           end}
        ])

      assert_receive {:area, %{x: 0, width: w1}}
      assert_receive {:area, %{x: x2, width: w2}}

      assert_in_delta w1, 100.0, 0.01
      assert_in_delta w2, 200.0, 0.01
      assert_in_delta x2, 100.0, 0.01
    end

    test "applies gap between columns", %{page: page} do
      _page =
        Layout.row(
          page,
          {0, 700},
          {310, 50},
          [
            {1,
             fn page, area ->
               send(self(), {:area, 1, area})
               page
             end},
            {1,
             fn page, area ->
               send(self(), {:area, 2, area})
               page
             end}
          ],
          gap: 10
        )

      assert_receive {:area, 1, %{x: 0, width: w1}}
      assert_receive {:area, 2, %{x: x2}}

      assert_in_delta w1, 150.0, 0.01
      assert_in_delta x2, 160.0, 0.01
    end
  end

  describe "column/5" do
    test "stacks items vertically", %{page: page} do
      _page =
        Layout.column(page, {50, 700}, {200, 300}, [
          {30,
           fn page, area ->
             send(self(), {:area, 1, area})
             page
           end},
          {40,
           fn page, area ->
             send(self(), {:area, 2, area})
             page
           end}
        ])

      assert_receive {:area, 1, %{y: 700, height: 30}}
      assert_receive {:area, 2, %{y: 670, height: 40}}
    end

    test "applies gap between rows", %{page: page} do
      _page =
        Layout.column(
          page,
          {50, 700},
          {200, 300},
          [
            {30,
             fn page, area ->
               send(self(), {:area, 1, area})
               page
             end},
            {40,
             fn page, area ->
               send(self(), {:area, 2, area})
               page
             end}
          ],
          gap: 5
        )

      assert_receive {:area, 1, %{y: 700}}
      assert_receive {:area, 2, %{y: 665}}
    end
  end
end
