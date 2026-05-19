defmodule Pdf.Reader.CID.CodespaceTest do
  use ExUnit.Case, async: true

  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7.6 — Codespace ranges (shortest-match rule)
  # - Adobe Tech Note #5099 — CMap and CIDFont Files Specification
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

  alias Pdf.Reader.CID.Codespace

  # Codespace map used across most tests:
  # 1-byte range: 0x00–0x7F (ASCII-like)
  # 2-byte range: 0x8000–0xFFFF (high-bytes)
  @cs %{1 => [{0x00, 0x7F}], 2 => [{0x8000, 0xFFFF}]}

  describe "tokenize/2 — S-PCM5, S-PCM6, R-PCM12, R-PCM13, R-PCM14" do
    test "empty binary returns empty list" do
      assert Codespace.tokenize(<<>>, @cs) == []
    end

    test "single 1-byte match returns [code]" do
      assert Codespace.tokenize(<<0x41>>, @cs) == [0x41]
    end

    test "single 2-byte match returns [code]" do
      assert Codespace.tokenize(<<0x81, 0x40>>, @cs) == [0x8140]
    end

    test "mixed 1-byte and 2-byte sequence returns both codes" do
      assert Codespace.tokenize(<<0x41, 0x81, 0x40>>, @cs) == [0x41, 0x8140]
    end

    test "byte with no matching codespace range is dropped silently" do
      # 0xFF is not in 1-byte range (0x00–0x7F), and is not a valid 2-byte start
      # (0xFF40 is within 0x8000–0xFFFF but here only one byte present)
      assert Codespace.tokenize(<<0xFF>>, @cs) == []
    end

    test "malformed prefix is dropped byte-by-byte until match found" do
      # 0xFF, 0xFF both dropped (0xFF not in 1-byte; 0xFFFF is in 2-byte but only
      # 1-byte range here for 0xFF single byte first, then 0xFF again)
      # Actually 0xFF is NOT in 1-byte range (>0x7F), and 0xFFFF IS in 2-byte range —
      # so <<0xFF, 0xFF>> → 2-byte 0xFFFF → [0xFFFF]... but then 0x41 follows.
      # To force a real drop: use codespace with only 1-byte range, send 0xFF 0xFF 0x41.
      cs1 = %{1 => [{0x00, 0x7F}]}
      assert Codespace.tokenize(<<0xFF, 0xFF, 0x41>>, cs1) == [0x41]
    end

    test "shortest match wins — 1-byte codespace prefers 1 byte over 2-byte range" do
      # With both 1-byte {0x40,0x40} and 2-byte {0x4040,0x40FF} in codespaces,
      # 0x40 matches the 1-byte range first (length 1 tried before length 2).
      # Then 0x80 has no 1-byte match and 0x80?? has no 2-byte match → dropped.
      cs = %{1 => [{0x40, 0x40}], 2 => [{0x4040, 0x40FF}]}
      assert Codespace.tokenize(<<0x40, 0x80>>, cs) == [0x40]
    end

    test "multiple consecutive 1-byte codes are all tokenized" do
      assert Codespace.tokenize(<<0x20, 0x41, 0x7F>>, @cs) == [0x20, 0x41, 0x7F]
    end

    test "multiple 2-byte codes in sequence" do
      assert Codespace.tokenize(<<0x81, 0x40, 0x82, 0x50>>, @cs) == [0x8140, 0x8250]
    end

    test "drops leading out-of-range byte and continues tokenizing" do
      # 0x80 alone is NOT in 1-byte range (>0x7F); 0x8041 IS in 2-byte range.
      # So first, length=1: 0x80 not in 1-byte. Then length=2: 0x8041 in 2-byte → match.
      assert Codespace.tokenize(<<0x80, 0x41>>, @cs) == [0x8041]
    end
  end
end
