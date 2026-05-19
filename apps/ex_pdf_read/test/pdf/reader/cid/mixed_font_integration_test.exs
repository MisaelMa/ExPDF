defmodule Pdf.Reader.CID.MixedFontIntegrationTest do
  use ExUnit.Case, async: true

  # Integration test: PDF with both a simple (Helvetica) font and a
  # Type0/Identity-H CID font on the same page.
  #
  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts
  # - PDF 1.7 § 9.6 — Type 1 Fonts
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  #
  # CID values:
  # - CID 843 → U+3042 (あ) in Adobe-Japan1

  # ---------------------------------------------------------------------------
  # 7.2 — Mixed simple + CID fonts (S-CID12, R-CID12, R-CID13b)
  # ---------------------------------------------------------------------------

  describe "mixed simple + CID fonts in same PDF (S-CID12)" do
    test "Helvetica text and Japan1 CID text both decode correctly" do
      bin = build_mixed_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)

      # Should have at least 2 text runs
      assert length(runs) >= 2

      texts = Enum.map(runs, & &1.text)

      # Simple font run: "Hi" via Helvetica (WinAnsiEncoding)
      assert Enum.any?(texts, &String.contains?(&1, "Hi"))

      # CID font run: あ (U+3042) via Japan1
      assert Enum.any?(texts, &String.contains?(&1, "あ"))
    end

    test "all runs have valid UTF-8 text" do
      bin = build_mixed_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)

      for run <- runs do
        assert String.valid?(run.text), "Run text is not valid UTF-8: #{inspect(run.text)}"
      end
    end

    test "simple font run has no unresolved glyphs" do
      bin = build_mixed_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)

      # The Helvetica run for "Hi" should have no unresolved glyphs
      helvetica_runs = Enum.filter(runs, &String.contains?(&1.text, "Hi"))
      assert length(helvetica_runs) >= 1

      for run <- helvetica_runs do
        assert run.unresolved == []
      end
    end

    test "CID font run resolves Japan1 CID to correct Unicode" do
      bin = build_mixed_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)

      cid_runs = Enum.filter(runs, &String.contains?(&1.text, "あ"))
      assert length(cid_runs) >= 1

      for run <- cid_runs do
        assert run.unresolved == []
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Build a PDF with two font resources:
  # - F1: Helvetica (simple, WinAnsiEncoding) — writes "Hi" (ASCII bytes 0x48, 0x69)
  # - F2: Type0/Identity-H/Japan1 — writes CID 843 (あ, <<0x03, 0x4B>>)
  defp build_mixed_pdf do
    # Content stream: set Helvetica, write "Hi"; then switch to CID font, write あ
    content_stream =
      "BT /F1 12 Tf 100 700 Td (Hi) Tj 0 -20 Td /F2 12 Tf <034B> Tj ET"

    content_length = byte_size(content_stream)

    obj1 = "<</Type /Catalog /Pages 2 0 R>>"
    obj2 = "<</Type /Pages /Kids [3 0 R] /Count 1>>"

    obj3 =
      "<</Type /Page /Parent 2 0 R " <>
        "/MediaBox [0 0 612 792] " <>
        "/Contents 4 0 R " <>
        "/Resources <</Font <</F1 5 0 R /F2 6 0 R>>>>>>"

    obj4 = "<</Length #{content_length}>>\nstream\n#{content_stream}\nendstream"

    # F1: Helvetica (simple)
    obj5 =
      "<</Type /Font /Subtype /Type1 /BaseFont /Helvetica " <>
        "/Encoding /WinAnsiEncoding>>"

    # F2: Type0/Identity-H CID font with Japan1 CIDSystemInfo
    obj6 =
      "<</Type /Font /Subtype /Type0 /BaseFont /HeiseiKakuGo-W5 " <>
        "/Encoding /Identity-H /DescendantFonts [7 0 R]>>"

    obj7 =
      "<</Type /Font /Subtype /CIDFontType2 /BaseFont /HeiseiKakuGo-W5 " <>
        "/CIDSystemInfo <</Registry (Adobe) /Ordering (Japan1) /Supplement 6>> " <>
        "/CIDToGIDMap /Identity>>"

    parts = [
      {"1 0", obj1},
      {"2 0", obj2},
      {"3 0", obj3},
      {"4 0", obj4},
      {"5 0", obj5},
      {"6 0", obj6},
      {"7 0", obj7}
    ]

    build_pdf_binary(parts)
  end

  defp build_pdf_binary(parts) do
    header = "%PDF-1.4\n"

    body_parts =
      Enum.map(parts, fn {ref, content} ->
        "#{ref} obj\n#{content}\nendobj\n"
      end)

    {offsets, _} =
      Enum.map_reduce(body_parts, byte_size(header), fn part, acc ->
        {acc, acc + byte_size(part)}
      end)

    body = Enum.join(body_parts)
    xref_offset = byte_size(header) + byte_size(body)
    count = length(parts)

    entries =
      Enum.map_join(offsets, fn off ->
        String.pad_leading(Integer.to_string(off), 10, "0") <> " 00000 n\r\n"
      end)

    xref = "xref\n0 #{count + 1}\n0000000000 65535 f\r\n#{entries}"
    trailer = "trailer\n<</Size #{count + 1} /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> body <> xref <> trailer
  end
end
