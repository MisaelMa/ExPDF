defmodule Pdf.Reader.AGLTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.AGL

  describe "glyph_to_unicode/1" do
    test "returns {:ok, codepoint} for known glyph name 'A'" do
      assert AGL.glyph_to_unicode("A") == {:ok, 0x0041}
    end

    test "returns {:ok, codepoint} for known glyph name 'space'" do
      assert AGL.glyph_to_unicode("space") == {:ok, 0x0020}
    end

    test "returns {:ok, codepoint} for known glyph name 'eacute'" do
      assert AGL.glyph_to_unicode("eacute") == {:ok, 0x00E9}
    end

    test "returns {:ok, codepoint} for known glyph name 'Euro'" do
      assert AGL.glyph_to_unicode("Euro") == {:ok, 0x20AC}
    end

    test "returns :error for unknown glyph name" do
      assert AGL.glyph_to_unicode("notAGlyphName_xyz") == :error
    end

    test "returns :error for empty string" do
      assert AGL.glyph_to_unicode("") == :error
    end
  end
end
