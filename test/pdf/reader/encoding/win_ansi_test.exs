defmodule Pdf.Reader.Encoding.WinAnsiTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encoding.WinAnsi

  describe "decode/1" do
    test "maps byte 0xE9 to U+00E9 (eacute)" do
      # WinAnsi 0xE9 → U+00E9 (LATIN SMALL LETTER E WITH ACUTE)
      assert WinAnsi.decode(0xE9) == 0x00E9
    end

    test "maps byte 0x41 to U+0041 (letter A — ASCII passthrough)" do
      assert WinAnsi.decode(0x41) == 0x0041
    end

    test "maps byte 0x80 to U+20AC (Euro sign)" do
      # WinAnsi 0x80 → U+20AC (EURO SIGN)
      assert WinAnsi.decode(0x80) == 0x20AC
    end

    test "maps byte 0x8E to U+017D (Zcaron)" do
      # WinAnsi 0x8E → U+017D (LATIN CAPITAL LETTER Z WITH CARON)
      assert WinAnsi.decode(0x8E) == 0x017D
    end
  end
end
