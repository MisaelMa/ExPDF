defmodule Pdf.Reader.ImageTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Image

  # Spec reference: PDF 1.7 § 8.3.3 (coordinate systems / matrix math),
  #                 § 8.9.5 (image dictionaries — image occupies unit square).
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

  # ---------------------------------------------------------------------------
  # 1.1 — new struct fields have correct defaults
  # ---------------------------------------------------------------------------

  describe "Image struct — new CTM fields (R-CTM1, R-CTM2)" do
    test "bare %Image{} has identity CTM default" do
      img = %Image{}
      assert img.ctm == {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}
    end

    test "bare %Image{} has render_width default 0.0" do
      img = %Image{}
      assert img.render_width == 0.0
    end

    test "bare %Image{} has render_height default 0.0" do
      img = %Image{}
      assert img.render_height == 0.0
    end

    test "bare %Image{} has rotation_radians default 0.0" do
      img = %Image{}
      assert img.rotation_radians == 0.0
    end

    test "width and height remain as pixel-dimension fields (nil default after spec change)" do
      # R-CTM2: :width and :height are pixel dims from /Width /Height, not render dims.
      # After Phase 1.2, their default changes from 0.0 to nil.
      img = %Image{}
      assert img.width == nil
      assert img.height == nil
    end

    test "existing fields still have expected defaults" do
      img = %Image{}
      assert img.x == 0.0
      assert img.y == 0.0
      assert img.page == nil
      assert img.ref == nil
    end

    test "CTM fields can be set in struct literal" do
      img = %Image{
        ctm: {200.0, 0.0, 0.0, 100.0, 50.0, 60.0},
        render_width: 200.0,
        render_height: 100.0,
        rotation_radians: 0.0
      }

      assert img.ctm == {200.0, 0.0, 0.0, 100.0, 50.0, 60.0}
      assert img.render_width == 200.0
      assert img.render_height == 100.0
      assert img.rotation_radians == 0.0
    end
  end
end
