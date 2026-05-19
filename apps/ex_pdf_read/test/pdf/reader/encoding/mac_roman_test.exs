defmodule Pdf.Reader.Encoding.MacRomanTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encoding.MacRoman

  describe "decode/1 — ASCII range (identity)" do
    test "0x20 (space)", do: assert(MacRoman.decode(0x20) == 0x0020)
    test "0x41 (A)", do: assert(MacRoman.decode(0x41) == 0x0041)
    test "0x61 (a)", do: assert(MacRoman.decode(0x61) == 0x0061)
    test "0x7E (~)", do: assert(MacRoman.decode(0x7E) == 0x007E)
  end

  describe "decode/1 — high bytes vs Apple ROMAN.TXT" do
    # Each assertion below is sourced from
    # https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/ROMAN.TXT

    test "0x80 → U+00C4 (Ä, A diaeresis)" do
      assert MacRoman.decode(0x80) == 0x00C4
    end

    test "0x8E → U+00E9 (é, e acute) — common Spanish/French character" do
      assert MacRoman.decode(0x8E) == 0x00E9
    end

    test "0x96 → U+00F1 (ñ, n tilde)" do
      assert MacRoman.decode(0x96) == 0x00F1
    end

    test "0xA9 → U+00A9 (©, copyright sign)" do
      assert MacRoman.decode(0xA9) == 0x00A9
    end

    test "0xAA → U+2122 (™, trade mark)" do
      assert MacRoman.decode(0xAA) == 0x2122
    end

    test "0xC9 → U+2026 (…, horizontal ellipsis)" do
      assert MacRoman.decode(0xC9) == 0x2026
    end

    test "0xDB → U+20AC (€, euro sign — added in Mac OS 8.5)" do
      assert MacRoman.decode(0xDB) == 0x20AC
    end

    test "0xDE → U+FB01 (fi ligature)" do
      assert MacRoman.decode(0xDE) == 0xFB01
    end

    test "0xF0 → U+F8FF (Apple logo, private-use area)" do
      assert MacRoman.decode(0xF0) == 0xF8FF
    end

    test "0xFF → U+02C7 (caron)" do
      assert MacRoman.decode(0xFF) == 0x02C7
    end
  end

  describe "decode/1 — table coverage" do
    test "ROMAN.TXT defines 223 byte→codepoint entries" do
      # The Apple ROMAN.TXT file leaves several high-byte slots undefined.
      # 223 is the count after stripping comments, blank lines, and the
      # explicit 'undefined' entries.
      assert MacRoman.entry_count() == 223
    end

    test "an undefined byte returns :undefined" do
      # The file does not map 0x7F (DEL) explicitly — verify the
      # fallback clause works.
      assert MacRoman.decode(0x7F) == :undefined
    end
  end
end
