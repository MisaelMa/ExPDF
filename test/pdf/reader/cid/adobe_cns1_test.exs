defmodule Pdf.Reader.CID.AdobeCNS1Test do
  use ExUnit.Case, async: true

  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7.5 — Predefined CMaps
  # - Adobe-CNS1: https://github.com/adobe-type-tools/Adobe-CNS1
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

  alias Pdf.Reader.CID.AdobeCNS1

  describe "lookup/1 — S-CID9" do
    test "CID 1 returns {:ok, 0x0020} (space — control point across all Adobe collections)" do
      assert AdobeCNS1.lookup(1) == {:ok, 0x0020}
    end

    test "unknown CID 999_999 returns :error" do
      assert AdobeCNS1.lookup(999_999) == :error
    end

    test "CID 0 returns :error" do
      assert AdobeCNS1.lookup(0) == :error
    end

    test "CID 2 returns {:ok, codepoint} for a known entry" do
      assert {:ok, cp} = AdobeCNS1.lookup(2)
      assert is_integer(cp)
      assert cp > 0
    end
  end
end
