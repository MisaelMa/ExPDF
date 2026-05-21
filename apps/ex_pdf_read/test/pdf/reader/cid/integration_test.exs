defmodule Pdf.Reader.CID.IntegrationTest do
  use ExUnit.Case, async: true

  # Integration tests: hand-crafted minimal binary PDFs with Type0/Identity-H fonts.
  #
  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts
  # - PDF 1.7 § 9.7.4 — CIDFonts
  # - PDF 1.7 § 9.7.5 — Predefined CMaps (Identity-H)
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  #
  # CID values used:
  # - CID 1   → U+0020 (space) in all Adobe collections
  # - CID 843 → U+3042 (あ, hiragana a) in Adobe-Japan1 (UniJIS-UCS2 column)

  # ---------------------------------------------------------------------------
  # 7.1 — Pure CID PDF: Type0/Identity-H with Japan1 CIDFont (S-CID2, S-CID3)
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_text/1 — pure CID PDF (S-CID2, S-CID3, R-CID3, R-CID4, R-CID5)" do
    test "CID 843 (<<0x03, 0x4B>>) resolves to hiragana あ (U+3042) via Japan1 registry" do
      # CID 843 → U+3042 (hiragana あ) per Adobe-Japan1 UniJIS-UCS2 table
      bin = build_cid_pdf(<<0x03, 0x4B>>, "Japan1")
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts, _doc} = Pdf.Reader.read_text(doc)
      full_text = Enum.join(texts)
      assert full_text == "あ"
    end

    test "CID 1 resolves to space (U+0020) via Japan1 registry (S-CID5)" do
      # CID 1 = space in all Adobe collections; read_text_with_positions preserves it
      bin = build_cid_pdf(<<0, 1>>, "Japan1")
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)
      assert length(runs) == 1
      [run] = runs
      # The decoder resolves CID 1 → U+0020 space
      assert run.text == " "
      assert run.unresolved == []
    end

    test "read_text_with_positions/1 returns a TextRun for a CID font" do
      bin = build_cid_pdf(<<0, 1>>, "Japan1")
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)
      assert runs != []
      [run | _] = runs
      assert is_binary(run.text)
      assert run.page == 1
    end

    test "two CIDs in sequence decode to two characters (R-CID3)" do
      # CID 1 (space) + CID 843 (あ) → " あ" via read_text_with_positions
      bin = build_cid_pdf(<<0, 1, 0x03, 0x4B>>, "Japan1")
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)
      assert length(runs) == 1
      [run] = runs
      # Both CIDs decoded in one Tj call → one text run
      assert run.text == " あ"
      assert run.unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # 7.2 — Unknown CID yields U+FFFD with sentinel
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_text/1 — unknown CID (S-CID6)" do
    test "CID 1 with unknown registry (custom) yields U+FFFD" do
      bin = build_cid_pdf(<<0, 1>>, "MyCustom")
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts, _doc} = Pdf.Reader.read_text(doc)
      full_text = Enum.join(texts)
      assert full_text == "�"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers: hand-craft a minimal binary PDF with a Type0/Identity-H font
  # ---------------------------------------------------------------------------

  # Build a minimal 1-page PDF with one Type0/Identity-H font whose CIDSystemInfo
  # has the given Ordering, and a Tj operator writing the given raw_bytes.
  defp build_cid_pdf(raw_bytes, ordering) do
    # Hex-encode the bytes for the Tj string in the content stream
    hex_bytes = Base.encode16(raw_bytes)

    content_stream = "BT /F1 12 Tf 100 700 Td <#{hex_bytes}> Tj ET"
    content_length = byte_size(content_stream)

    obj1 = "<</Type /Catalog /Pages 2 0 R>>"
    obj2 = "<</Type /Pages /Kids [3 0 R] /Count 1>>"

    obj3 =
      "<</Type /Page /Parent 2 0 R " <>
        "/MediaBox [0 0 612 792] " <>
        "/Contents 4 0 R " <>
        "/Resources <</Font <</F1 5 0 R>>>>>>"

    obj4 = "<</Length #{content_length}>>\nstream\n#{content_stream}\nendstream"

    obj5 =
      "<</Type /Font /Subtype /Type0 /BaseFont /Helvetica-Bold " <>
        "/Encoding /Identity-H /DescendantFonts [6 0 R]>>"

    obj6 =
      "<</Type /Font /Subtype /CIDFontType2 /BaseFont /Helvetica-Bold " <>
        "/CIDSystemInfo <</Registry (Adobe) /Ordering (#{ordering}) /Supplement 0>> " <>
        "/CIDToGIDMap /Identity>>"

    parts = [
      {"1 0", obj1},
      {"2 0", obj2},
      {"3 0", obj3},
      {"4 0", obj4},
      {"5 0", obj5},
      {"6 0", obj6}
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
