defmodule Pdf.Reader.EncodingTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encoding

  # Spec reference: PDF 1.7 § 9.6.5 (Type1 font encoding), § 9.10.3 (ToUnicode)
  #
  # The encoding cascade for each byte (highest priority first):
  #   1. ToUnicode CMap         → {:ok, codepoint}
  #   2. /Differences + AGL    → {:ok, codepoint}
  #   3. Base encoding table   → {:ok, codepoint}
  #   4. Fallback              → {:unresolved, glyph_name_or_byte}
  #
  # Inputs to resolve_byte/3:
  #   - byte  :: integer (0..255)
  #   - cmap  :: Pdf.Reader.CMap.t() | nil
  #   - opts  :: keyword with:
  #       :differences  :: %{integer => glyph_name} | nil
  #       :base_encoding :: :win_ansi | :mac_roman | :standard | nil
  #
  # Output: {:ok, codepoint :: integer} | {:unresolved, glyph_name_or_byte}

  # ---- 7.3.1 ToUnicode CMap wins (highest priority) ----

  describe "resolve_byte/3 — ToUnicode CMap (priority 1)" do
    test "returns codepoint from CMap when mapped" do
      alias Pdf.Reader.CMap

      cmap_bin = """
      begincmap
      1 beginbfchar
      <41> <0041>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)

      # 0x41 → U+0041 (A) — from CMap
      assert Encoding.resolve_byte(0x41, cmap, base_encoding: :win_ansi) == {:ok, 0x0041}
    end

    test "CMap overrides base encoding for same byte" do
      alias Pdf.Reader.CMap

      # Map 0x41 to U+0061 (lowercase 'a') — NOT what WinAnsi would give (it's A = 0x41)
      cmap_bin = """
      begincmap
      1 beginbfchar
      <41> <0061>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)

      assert Encoding.resolve_byte(0x41, cmap, base_encoding: :win_ansi) == {:ok, 0x0061}
    end
  end

  # ---- 7.3.2 /Differences + AGL (priority 2) ----

  describe "resolve_byte/3 — /Differences + AGL (priority 2)" do
    test "glyph name from /Differences resolved via AGL" do
      # /Differences says byte 0x41 → 'A' (glyph name "A")
      # AGL maps "A" → U+0041
      differences = %{0x41 => "A"}

      result =
        Encoding.resolve_byte(0x41, nil, differences: differences, base_encoding: :win_ansi)

      assert result == {:ok, 0x0041}
    end

    test "glyph name not in AGL falls through to unresolved" do
      # Hypothetical glyph name that doesn't exist in AGL
      differences = %{0x41 => "NotAGlyphName___xyz"}

      result =
        Encoding.resolve_byte(0x41, nil, differences: differences, base_encoding: :win_ansi)

      assert result == {:unresolved, "NotAGlyphName___xyz"}
    end

    test "differences only apply to mapped bytes; others fall through to base encoding" do
      differences = %{0x41 => "A"}

      # 0x42 not in differences → falls to base encoding (WinAnsi 0x42 = B = U+0042)
      result =
        Encoding.resolve_byte(0x42, nil, differences: differences, base_encoding: :win_ansi)

      assert result == {:ok, 0x0042}
    end
  end

  # ---- 7.3.3 Base encoding fallback (priority 3) ----

  describe "resolve_byte/3 — base encoding (priority 3)" do
    test "WinAnsi base encoding resolves ASCII byte" do
      # 0x48 = 'H' in WinAnsi → U+0048
      assert Encoding.resolve_byte(0x48, nil, base_encoding: :win_ansi) == {:ok, 0x0048}
    end

    test "MacRoman base encoding resolves known byte" do
      # MacRoman 0x8E → U+00E9 (é) per Apple ROMAN.TXT
      assert Encoding.resolve_byte(0x8E, nil, base_encoding: :mac_roman) == {:ok, 0x00E9}
    end

    test "StandardEncoding base resolves named glyph" do
      # StandardEncoding 0x27 → quoteright → U+2019
      # Control point from PDF 1.7 Annex D.2 + AGL
      assert Encoding.resolve_byte(0x27, nil, base_encoding: :standard) == {:ok, 0x2019}
    end
  end

  # ---- 7.3.4 Unresolved fallback (priority 4) ----

  describe "resolve_byte/3 — unresolved fallback (priority 4)" do
    test "unmapped byte with nil base encoding returns unresolved with byte marker" do
      result = Encoding.resolve_byte(0xFF, nil, base_encoding: nil)

      assert result == {:unresolved, "byte:0xFF"}
    end

    test "byte undefined in base encoding returns unresolved" do
      # StandardEncoding has many undefined slots (e.g. 0x01 is not mapped)
      # Returns {:unresolved, "byte:0x01"} since no glyph name is available
      result = Encoding.resolve_byte(0x01, nil, base_encoding: :standard)

      assert {:unresolved, _} = result
    end
  end
end
