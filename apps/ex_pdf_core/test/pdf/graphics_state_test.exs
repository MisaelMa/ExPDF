defmodule Pdf.GraphicsStateTest do
  use Pdf.Case, async: true

  alias Pdf.{Page, Fonts, ObjectCollection}

  setup do
    objects = ObjectCollection.new()
    fonts = Fonts.new()
    page = Page.new(fonts: fonts, objects: objects, compress: false)
    {:ok, page: page}
  end

  describe "set_fill_opacity/2" do
    test "emits gs command and registers ExtGState", %{page: page} do
      page = Page.set_fill_opacity(page, 0.5)
      assert export(page) =~ "/GS1 gs"
      assert map_size(page.ext_g_states) == 1
    end
  end

  describe "set_stroke_opacity/2" do
    test "emits gs command and registers ExtGState", %{page: page} do
      page = Page.set_stroke_opacity(page, 0.7)
      assert export(page) =~ "/GS1 gs"
      assert map_size(page.ext_g_states) == 1
    end
  end

  describe "set_opacity/2" do
    test "sets both fill and stroke opacity", %{page: page} do
      page = Page.set_opacity(page, 0.3)
      assert export(page) =~ "/GS1 gs"
      assert map_size(page.ext_g_states) == 1
    end
  end

  describe "opacity deduplication" do
    test "reuses ExtGState for same opacity values", %{page: page} do
      page =
        page
        |> Page.set_fill_opacity(0.5)
        |> Page.set_fill_opacity(0.5)

      assert map_size(page.ext_g_states) == 1
      assert export(page) =~ "/GS1 gs\n/GS1 gs"
    end

    test "creates separate ExtGStates for different opacity values", %{page: page} do
      page =
        page
        |> Page.set_fill_opacity(0.5)
        |> Page.set_fill_opacity(0.3)

      assert map_size(page.ext_g_states) == 2
    end
  end

  describe "rotate/2" do
    test "emits cm command with rotation matrix", %{page: page} do
      page = Page.rotate(page, 90)
      output = export(page)
      # cos(90°) ≈ 0, sin(90°) ≈ 1
      assert output =~ "cm"
    end
  end

  describe "translate/2" do
    test "emits cm command with translation", %{page: page} do
      page = Page.translate(page, {100, 200})
      assert export(page) == "1 0 0 1 100 200 cm\n"
    end
  end

  describe "scale/2" do
    test "emits cm command with scale factors", %{page: page} do
      page = Page.scale(page, {2, 3})
      assert export(page) == "2 0 0 3 0 0 cm\n"
    end
  end

  describe "transform/2" do
    test "emits cm command with arbitrary matrix", %{page: page} do
      page = Page.transform(page, {1, 0, 0, 1, 50, 50})
      assert export(page) == "1 0 0 1 50 50 cm\n"
    end
  end

  describe "save_state/restore_state with transforms" do
    test "isolates transformations", %{page: page} do
      page =
        page
        |> Page.save_state()
        |> Page.translate({100, 200})
        |> Page.rotate(45)
        |> Page.restore_state()

      output = export(page)
      assert output =~ "q\n"
      assert output =~ "1 0 0 1 100 200 cm\n"
      assert output =~ "cm\n"
      assert output =~ "Q\n"
    end
  end
end
