defmodule Pdf.CursorTest do
  use ExUnit.Case, async: true

  alias Pdf.{Page, Fonts, ObjectCollection}

  setup do
    objects = ObjectCollection.new()
    fonts = Fonts.new()
    page = Page.new(size: :a4, fonts: fonts, objects: objects, compress: false)
    {:ok, page: page}
  end

  describe "cursor Y (existing)" do
    test "initialized to page height", %{page: page} do
      %{height: height} = Page.size(page)
      assert Page.cursor(page) == height
    end

    test "set_cursor/2 sets Y", %{page: page} do
      page = Page.set_cursor(page, 500)
      assert Page.cursor(page) == 500
    end

    test "move_down/2 decreases Y", %{page: page} do
      page = page |> Page.set_cursor(500) |> Page.move_down(30)
      assert Page.cursor(page) == 470
    end
  end

  describe "cursor X (new)" do
    test "initialized to 0", %{page: page} do
      assert page.cursor_x == 0
    end

    test "set_cursor_x/2 sets X", %{page: page} do
      page = Page.set_cursor_x(page, 100)
      assert page.cursor_x == 100
    end

    test "move_right/2 increases X", %{page: page} do
      page = page |> Page.set_cursor_x(50) |> Page.move_right(30)
      assert page.cursor_x == 80
    end

    test "reset_x/1 returns X to 0", %{page: page} do
      page = page |> Page.set_cursor_x(100) |> Page.reset_x()
      assert page.cursor_x == 0
    end
  end

  describe "cursor_xy/1" do
    test "returns both coordinates", %{page: page} do
      %{height: height} = Page.size(page)
      page = Page.set_cursor_x(page, 42)
      assert Page.cursor_xy(page) == %{x: 42, y: height}
    end

    test "reflects changes from move_down and move_right", %{page: page} do
      page =
        page
        |> Page.set_cursor(700)
        |> Page.set_cursor_x(50)
        |> Page.move_down(20)
        |> Page.move_right(10)

      assert Page.cursor_xy(page) == %{x: 60, y: 680}
    end
  end

  describe "Pdf-level cursor API" do
    test "cursor_xy returns %{x, y}" do
      pdf = Pdf.new(size: :a4)
      pos = Pdf.cursor_xy(pdf)
      assert is_map(pos)
      assert Map.has_key?(pos, :x)
      assert Map.has_key?(pos, :y)
      assert pos.x == 0
    end

    test "move_right and reset_x" do
      pdf =
        Pdf.new(size: :a4)
        |> Pdf.move_right(50)

      assert Pdf.cursor_xy(pdf).x == 50

      pdf = Pdf.reset_x(pdf)
      assert Pdf.cursor_xy(pdf).x == 0
    end

    test "set_cursor_x" do
      pdf =
        Pdf.new(size: :a4)
        |> Pdf.set_cursor_x(200)

      assert Pdf.cursor_xy(pdf).x == 200
    end
  end
end
