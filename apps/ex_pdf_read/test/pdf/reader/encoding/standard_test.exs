defmodule Pdf.Reader.Encoding.StandardEncodingTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encoding.StandardEncoding

  describe "decode/1 — ASCII identity range" do
    test "0x21 → U+0021 (exclam)", do: assert(StandardEncoding.decode(0x21) == 0x0021)
    test "0x41 → U+0041 (A)", do: assert(StandardEncoding.decode(0x41) == 0x0041)
    test "0x61 → U+0061 (a)", do: assert(StandardEncoding.decode(0x61) == 0x0061)
    test "0x7E → U+007E (asciitilde)", do: assert(StandardEncoding.decode(0x7E) == 0x007E)
  end

  describe "decode/1 — PDF Standard Encoding quirks" do
    test "0x27 → U+2019 (quoteright) — Standard Encoding does NOT map 0x27 to apostrophe" do
      assert StandardEncoding.decode(0x27) == 0x2019
    end

    test "0x60 → U+2018 (quoteleft) — backtick is the open single quote in StdEnc" do
      assert StandardEncoding.decode(0x60) == 0x2018
    end

    test "0xA9 → U+0027 (quotesingle) — the only place the straight apostrophe lives in StdEnc" do
      assert StandardEncoding.decode(0xA9) == 0x0027
    end
  end

  describe "decode/1 — high-byte entries vs PDF 1.7 Annex D.2" do
    test "0xA1 → U+00A1 (exclamdown)", do: assert(StandardEncoding.decode(0xA1) == 0x00A1)
    test "0xA6 → U+0192 (florin)", do: assert(StandardEncoding.decode(0xA6) == 0x0192)
    test "0xAB → U+00AB (guillemotleft)", do: assert(StandardEncoding.decode(0xAB) == 0x00AB)
    test "0xAC → U+2039 (guilsinglleft)", do: assert(StandardEncoding.decode(0xAC) == 0x2039)
    test "0xAE → U+FB01 (fi ligature)", do: assert(StandardEncoding.decode(0xAE) == 0xFB01)
    test "0xB1 → U+2013 (endash)", do: assert(StandardEncoding.decode(0xB1) == 0x2013)
    test "0xB2 → U+2020 (dagger)", do: assert(StandardEncoding.decode(0xB2) == 0x2020)
    test "0xBC → U+2026 (ellipsis)", do: assert(StandardEncoding.decode(0xBC) == 0x2026)
    test "0xC1 → U+0060 (grave accent)", do: assert(StandardEncoding.decode(0xC1) == 0x0060)
    test "0xE1 → U+00C6 (AE ligature)", do: assert(StandardEncoding.decode(0xE1) == 0x00C6)
    test "0xE9 → U+00D8 (Oslash)", do: assert(StandardEncoding.decode(0xE9) == 0x00D8)
    test "0xEA → U+0152 (OE ligature)", do: assert(StandardEncoding.decode(0xEA) == 0x0152)

    test "0xFB → U+00DF (germandbls / eszett)",
      do: assert(StandardEncoding.decode(0xFB) == 0x00DF)
  end

  describe "decode/1 — undefined slots" do
    test "0x00 (NUL) is undefined in StdEnc" do
      assert StandardEncoding.decode(0x00) == :undefined
    end

    test "0x80 (high control range) is undefined in StdEnc" do
      assert StandardEncoding.decode(0x80) == :undefined
    end

    test "0xFF is undefined in StdEnc" do
      assert StandardEncoding.decode(0xFF) == :undefined
    end
  end

  describe "decode/1 — table size" do
    test "StdEnc defines exactly 149 byte slots (per Annex D.2)" do
      assert StandardEncoding.entry_count() == 149
    end
  end
end
