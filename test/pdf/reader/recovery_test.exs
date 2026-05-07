defmodule Pdf.Reader.RecoveryTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Phase 1 — Foundation: recovery_log accessor + recover_mode threading
  #
  # Spec citations:
  #   § 7.5 — PDF file structure
  #   § 7.5.4 — Cross-reference table
  #   § 7.5.5 — File trailer
  #   § 7.7.3 — Page tree
  #   § 7.8   — Content streams
  #   § 9.6   — Font dictionaries
  #   § 9.10  — Extraction of text content
  # ---------------------------------------------------------------------------

  # Minimal valid single-page PDF binary built inline (no Hex dependencies).
  # Object layout:
  #   1 0 obj — pages node (Type Pages, Count 1, Kids [2 0 R])
  #   2 0 obj — page node   (Type Page, Parent 1 0 R, MediaBox, Resources, Contents 3 0 R)
  #   3 0 obj — content stream ("BT /F1 12 Tf 100 700 Td (Hello) Tj ET")
  #   4 0 obj — font dict   (Type Font, Subtype Type1, BaseFont Helvetica)
  defp build_minimal_valid_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Pages /Kids [2 0 R] /Count 1>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)

    obj2 =
      "2 0 obj\n" <>
        "<</Type /Page /Parent 1 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 3 0 R>>\n" <>
        "endobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj3 = "3 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica>>\nendobj\n"

    xref_offset = obj4_offset + byte_size(obj4)

    xref =
      "xref\n0 5\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n"

    trailer =
      "trailer\n<</Size 5 /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> xref <> trailer
  end

  defp pad_offset(n) do
    n |> Integer.to_string() |> String.pad_leading(10, "0")
  end

  # ---------------------------------------------------------------------------
  # Three-page PDF where page 2 references a non-existent content stream object.
  #
  # Object layout:
  #   1 0 obj  — catalog (Type Catalog, Pages 2 0 R)
  #   2 0 obj  — pages node (Type Pages, Count 3, Kids [3 0 R, 5 0 R, 7 0 R])
  #   3 0 obj  — page 1    (Type Page, Contents 4 0 R, Resources ...)
  #   4 0 obj  — content 1 ("BT /F1 12 Tf 100 700 Td (Page1) Tj ET")
  #   5 0 obj  — page 2    (Type Page, Contents 98 0 R — MISSING in xref)
  #   6 0 obj  — page 3    (Type Page, Contents 7 0 R, Resources ...)
  #   7 0 obj  — content 3 ("BT /F1 12 Tf 100 700 Td (Page3) Tj ET")
  #   8 0 obj  — font dict  (Type Font, Subtype Type1, BaseFont Helvetica, WinAnsiEncoding)
  #
  # Page 2 /Contents → obj 98 which is NOT in the xref table.
  # ObjectResolver.resolve returns {:error, {:unresolved_ref, {98, 0}}}, which
  # causes extract_page_runs to return {:error, _} → triggers per-page isolation.
  defp build_three_page_truncated_pdf do
    header = "%PDF-1.4\n"

    font_resources = "/Resources <</Font <</F1 8 0 R>>>>"

    # ---------- obj 1 — catalog ----------
    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    # ---------- obj 2 — pages node ----------
    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 5 0 R 6 0 R] /Count 3>>\nendobj\n"

    # ---------- obj 3 — page 1 ----------
    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
        font_resources <> " /Contents 4 0 R>>\nendobj\n"

    # ---------- obj 4 — content 1 (valid) ----------
    obj4_offset = obj3_offset + byte_size(obj3)
    content1 = "BT /F1 12 Tf 100 700 Td (Page1) Tj ET"

    obj4 =
      "4 0 obj\n<</Length #{byte_size(content1)}>>\nstream\n#{content1}\nendstream\nendobj\n"

    # ---------- obj 5 — page 2 (Contents → missing obj 98) ----------
    # obj 98 does not exist in the xref — resolve will return {:error, _}.
    obj5_offset = obj4_offset + byte_size(obj4)

    obj5 =
      "5 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
        font_resources <> " /Contents 98 0 R>>\nendobj\n"

    # ---------- obj 6 — page 3 ----------
    obj6_offset = obj5_offset + byte_size(obj5)

    obj6 =
      "6 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
        font_resources <> " /Contents 7 0 R>>\nendobj\n"

    # ---------- obj 7 — content 3 (valid) ----------
    obj7_offset = obj6_offset + byte_size(obj6)
    content3 = "BT /F1 12 Tf 100 700 Td (Page3) Tj ET"

    obj7 =
      "7 0 obj\n<</Length #{byte_size(content3)}>>\nstream\n#{content3}\nendstream\nendobj\n"

    # ---------- obj 8 — font (with WinAnsiEncoding so ASCII bytes map cleanly) ----------
    obj8_offset = obj7_offset + byte_size(obj7)

    obj8 =
      "8 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    xref_offset = obj8_offset + byte_size(obj8)

    xref =
      "xref\n0 9\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n" <>
        pad_offset(obj7_offset) <> " 00000 n\r\n" <>
        pad_offset(obj8_offset) <> " 00000 n\r\n"

    # Note: Size 9 means objects 0-8; obj 98 deliberately absent.
    trailer =
      "trailer\n<</Size 9 /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <>
      obj1 <>
      obj2 <>
      obj3 <>
      obj4 <>
      obj5 <>
      obj6 <>
      obj7 <>
      obj8 <>
      xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # PDF where page 1 references font /F1 → obj 99 (non-existent in xref).
  # Used for R-2 font decoder lenience tests (tasks 2.4 and 2.5).
  #
  # Object layout:
  #   1 0 obj  — catalog
  #   2 0 obj  — pages node (Count 1, Kids [3 0 R])
  #   3 0 obj  — page 1 (Contents 4 0 R, Font /F1 → ref 99 0 R which does not exist)
  #   4 0 obj  — content stream "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
  # No obj 99 in xref — ObjectResolver will return {:error, _} on resolution.
  defp build_bad_font_ref_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 99 0 R>>>> /Contents 4 0 R>>\n" <>
        "endobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj4 = "4 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    xref_offset = obj4_offset + byte_size(obj4)

    xref =
      "xref\n0 5\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n"

    # Note: obj 99 is NOT in the xref — deliberately missing
    trailer =
      "trailer\n<</Size 5 /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # 1.1 — recovery_log/1 returns [] on a valid doc opened without recover: true
  #
  # Acceptance criteria (task): fails with UndefinedFunctionError before GREEN
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.recovery_log/1" do
    test "returns [] for a valid doc opened without recover: true" do
      bin = build_minimal_valid_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert Pdf.Reader.recovery_log(doc) == []
    end

    # ---------------------------------------------------------------------------
    # 1.2 — recovery_log/1 returns events in chronological (oldest-first) order
    #        after two synthetic log_recovery/2 calls.
    #
    # Acceptance criteria: fails before GREEN (log_recovery/2 missing)
    # ---------------------------------------------------------------------------

    test "returns events in chronological (oldest-first) order after two log_recovery calls" do
      bin = build_minimal_valid_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)

      # Prepend two synthetic events directly via Document.log_recovery/2
      doc2 = Pdf.Reader.Document.log_recovery(doc, {:xref_recovered, 5})
      doc3 = Pdf.Reader.Document.log_recovery(doc2, {:page_failed, 1, :truncated})

      log = Pdf.Reader.recovery_log(doc3)

      # Oldest event first
      assert [{:xref_recovered, 5}, {:page_failed, 1, :truncated}] = log
    end
  end

  # ---------------------------------------------------------------------------
  # 1.5 — do_open/2 stores recover_mode: true when open(bin, recover: true)
  #       and recover_mode: false when open(bin)
  #
  # Acceptance criteria: fails (option not wired) before GREEN
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.open/2 recover option" do
    test "stores recover_mode: false by default" do
      bin = build_minimal_valid_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert doc.recover_mode == false
    end

    test "stores recover_mode: true when recover: true opt is passed" do
      bin = build_minimal_valid_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)
      assert doc.recover_mode == true
    end
  end

  # ---------------------------------------------------------------------------
  # 1.7 — SMOKE: open a real valid PDF with recover: true;
  #        assert recovery_log(doc) == [] (no spurious recovery events)
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.open/2 with recover: true on a real PDF" do
    @describetag :fixtures

    test "recovery_log is empty for a well-formed PDF opened with recover: true" do
      bin = build_minimal_valid_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)
      assert Pdf.Reader.recovery_log(doc) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 2 — R-1: Per-page isolation (tasks 2.1 + 2.2)
  #
  # Spec citations:
  #   § 7.7.3 — Page tree
  #   § 7.8   — Content streams
  # ---------------------------------------------------------------------------

  describe "R-1: per-page isolation — recover mode" do
    # 2.1 RED: pages 1 and 3 succeed; page 2 fails; recovery_log has {:page_failed, 2, _}
    test "recover: true — pages 1 and 3 return text, page 2 failure is logged" do
      bin = build_three_page_truncated_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)
      {:ok, texts, updated_doc} = Pdf.Reader.read_text(doc)

      # Pages 1 and 3 should have text; page 2 is skipped
      page1_found = Enum.any?(texts, &String.contains?(&1, "Page1"))
      page3_found = Enum.any?(texts, &String.contains?(&1, "Page3"))
      assert page1_found, "Expected 'Page1' in texts, got: #{inspect(texts)}"
      assert page3_found, "Expected 'Page3' in texts, got: #{inspect(texts)}"

      log = Pdf.Reader.recovery_log(updated_doc)
      page_failed_events = Enum.filter(log, &match?({:page_failed, 2, _}, &1))

      assert length(page_failed_events) >= 1,
             "Expected {:page_failed, 2, _} in log, got: #{inspect(log)}"
    end

    # 2.2 RED: strict mode returns {:error, _} on the same truncated fixture
    test "recover: false (strict) — returns {:error, _} on missing page content ref" do
      bin = build_three_page_truncated_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_text(doc)

      # In strict mode the first page error must propagate
      assert match?({:error, _}, result),
             "Expected {:error, _} in strict mode, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3 — R-3: XRef linear scan (tasks 3.1–3.7)
  #
  # Spec citations:
  #   § 7.5.4 — Cross-reference table
  #   § 7.5.5 — File trailer
  #   § 7.5.8 — Cross-reference streams
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Fixture: valid PDF body with startxref pointing to garbage offset 999999.
  # The xref table and trailer are still present in the body, but the
  # startxref value is intentionally wrong so Trailer.locate_startxref succeeds
  # but XRef.load fails with :xref_offset_out_of_range.
  # ---------------------------------------------------------------------------
  defp build_corrupted_startxref_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 5 0 R>>\n" <>
        "endobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    obj5_offset = obj4_offset + byte_size(obj4)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj5 = "5 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    # _xref_offset is the true offset, but the trailer deliberately points to 999999
    # to force XRef.load failure and trigger linear scan recovery.
    _xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    # Deliberately wrong xref offset → XRef.load will fail
    trailer_str =
      "trailer\n<</Size 6 /Root 1 0 R>>\nstartxref\n999999\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer_str
  end

  # ---------------------------------------------------------------------------
  # Fixture: valid PDF body but trailing %%EOF and startxref stripped.
  # Trailer.locate_startxref will fail because %%EOF is absent.
  # ---------------------------------------------------------------------------
  defp build_no_eof_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 5 0 R>>\n" <>
        "endobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    obj5_offset = obj4_offset + byte_size(obj4)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj5 = "5 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    # _xref_offset would be the correct offset but this fixture omits the
    # startxref/%%EOF lines entirely to trigger Trailer.locate_startxref failure.
    _xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    # Include xref + trailer dict but strip the %%EOF and startxref lines
    trailer_dict = "trailer\n<</Size 6 /Root 1 0 R>>\n"

    # NOTE: no "startxref\nN\n%%EOF" → Trailer.locate_startxref returns {:error, :malformed}
    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer_dict
  end

  # ---------------------------------------------------------------------------
  # Fixture: binary with obj 5 appearing twice — gen 0 at lower offset,
  # gen 1 at higher offset. XRef.recover/1 should keep gen 1 only.
  # ---------------------------------------------------------------------------
  defp build_multi_gen_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 5 0 R>>\n" <>
        "endobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    # obj 5 gen 0 — lower offset (old revision)
    obj5_gen0_offset = obj4_offset + byte_size(obj4)
    content_old = "BT /F1 12 Tf 100 700 Td (Old) Tj ET"

    obj5_gen0 =
      "5 0 obj\n<</Length #{byte_size(content_old)}>>\nstream\n#{content_old}\nendstream\nendobj\n"

    # obj 5 gen 1 — higher offset (new revision, should win)
    obj5_gen1_offset = obj5_gen0_offset + byte_size(obj5_gen0)
    content_new = "BT /F1 12 Tf 100 700 Td (New) Tj ET"

    obj5_gen1 =
      "5 1 obj\n<</Length #{byte_size(content_new)}>>\nstream\n#{content_new}\nendstream\nendobj\n"

    # _xref_offset: correct offset but trailer deliberately uses 999999 to force recovery.
    _xref_offset = obj5_gen1_offset + byte_size(obj5_gen1)

    xref =
      "xref\n0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        # Point to gen 1 in the xref (but body has both)
        pad_offset(obj5_gen1_offset) <> " 00001 n\r\n"

    trailer_str =
      "trailer\n<</Size 6 /Root 1 0 R>>\nstartxref\n999999\n%%EOF\n"

    header <>
      obj1 <>
      obj2 <>
      obj3 <>
      obj4 <>
      obj5_gen0 <>
      obj5_gen1 <>
      xref <>
      trailer_str
  end

  # ---------------------------------------------------------------------------
  # Fixture: binary where " obj" appears inside a content stream (not at a
  # valid object header position). XRef.recover/1 must NOT pick up the false positive.
  #
  # The content stream contains the bytes "something obj" which would naively
  # match " obj" but lacks the required "\n<digits> <digits> " prefix.
  # ---------------------------------------------------------------------------
  defp build_false_positive_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 5 0 R>>\n" <>
        "endobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    obj5_offset = obj4_offset + byte_size(obj4)
    # The stream deliberately contains "something obj" — false positive for " obj" scan
    content = "BT /F1 12 Tf 100 700 Td (something obj here) Tj ET"
    obj5 = "5 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    # _xref_offset: correct offset but trailer deliberately uses 999999 to force recovery.
    _xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    trailer_str =
      "trailer\n<</Size 6 /Root 1 0 R>>\nstartxref\n999999\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer_str
  end

  # ---------------------------------------------------------------------------
  # 3.1 RED — corrupted startxref offset
  # ---------------------------------------------------------------------------

  describe "R-3: XRef linear scan — corrupted startxref" do
    # 3.1a: recover: true should succeed and log {:xref_recovered, n} where n > 0
    test "recover: true — corrupted startxref returns {:ok, doc} with xref_recovered in log" do
      bin = build_corrupted_startxref_pdf()
      result = Pdf.Reader.open(bin, recover: true)

      assert match?({:ok, _}, result),
             "Expected {:ok, doc}, got: #{inspect(result)}"

      {:ok, doc} = result
      log = Pdf.Reader.recovery_log(doc)
      xref_events = Enum.filter(log, &match?({:xref_recovered, _}, &1))

      assert length(xref_events) >= 1,
             "Expected {:xref_recovered, _} in log, got: #{inspect(log)}"

      [{:xref_recovered, n}] = Enum.take(xref_events, 1)
      assert n > 0, "Expected n > 0 in {:xref_recovered, #{n}}"
    end

    # 3.1b: strict mode should return {:error, _} on the same fixture
    test "recover: false (strict) — corrupted startxref returns {:error, _}" do
      bin = build_corrupted_startxref_pdf()
      result = Pdf.Reader.open(bin)

      assert match?({:error, _}, result),
             "Expected {:error, _} in strict mode, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # 3.2 RED — missing %%EOF
  # ---------------------------------------------------------------------------

  describe "R-3: XRef linear scan — missing %%EOF" do
    test "recover: true — no %%EOF returns {:ok, doc} and logs :eof_marker_missing and :xref_recovered" do
      bin = build_no_eof_pdf()
      result = Pdf.Reader.open(bin, recover: true)

      assert match?({:ok, _}, result),
             "Expected {:ok, doc}, got: #{inspect(result)}"

      {:ok, doc} = result
      log = Pdf.Reader.recovery_log(doc)

      eof_events = Enum.filter(log, &match?({:eof_marker_missing, :linear_scan_used}, &1))

      assert length(eof_events) >= 1,
             "Expected {:eof_marker_missing, :linear_scan_used} in log, got: #{inspect(log)}"

      xref_events = Enum.filter(log, &match?({:xref_recovered, _}, &1))

      assert length(xref_events) >= 1,
             "Expected {:xref_recovered, _} in log, got: #{inspect(log)}"
    end
  end

  # ---------------------------------------------------------------------------
  # 3.3 RED — multi-gen dedup: highest gen_num wins
  # ---------------------------------------------------------------------------

  describe "R-3: XRef.recover/1 — multi-gen dedup" do
    test "obj 5 with gen 0 and gen 1 — recovered table keeps gen 1 only" do
      bin = build_multi_gen_pdf()
      {:ok, entries, _trailer} = Pdf.Reader.XRef.recover(bin)

      # obj 5 should appear exactly once, at gen 1
      assert Map.has_key?(entries, {5, 1}),
             "Expected {5, 1} in recovered entries, keys: #{inspect(Map.keys(entries))}"

      refute Map.has_key?(entries, {5, 0}),
             "Expected {5, 0} to be absent (dedup should keep gen 1), keys: #{inspect(Map.keys(entries))}"
    end
  end

  # ---------------------------------------------------------------------------
  # 3.4 RED — false-positive guard: " obj" inside content stream not picked up
  # ---------------------------------------------------------------------------

  describe "R-3: XRef.recover/1 — false-positive guard" do
    test "' obj' inside a content stream is NOT picked up as an object header" do
      bin = build_false_positive_pdf()
      {:ok, entries, _trailer} = Pdf.Reader.XRef.recover(bin)

      # The only real objects are 1, 2, 3, 4, 5 — all at gen 0.
      # "something obj" inside the content stream of obj 5 must NOT generate
      # a spurious entry (e.g. a phantom obj with weird number parsed from the stream).
      obj_nums = entries |> Map.keys() |> Enum.map(fn {n, _g} -> n end) |> Enum.sort()

      # Valid object numbers are 1-5; no other numbers should appear
      assert Enum.all?(obj_nums, fn n -> n in 1..5 end),
             "Unexpected object numbers from false-positive: #{inspect(obj_nums)}"
    end

    # Triangulation: confirm real objects ARE found (so the previous assertion is non-trivial)
    test "real object headers ARE detected even when stream contains ' obj' substring" do
      bin = build_false_positive_pdf()
      {:ok, entries, _trailer} = Pdf.Reader.XRef.recover(bin)

      # All 5 real objects must be present
      assert Map.has_key?(entries, {1, 0}), "obj 1 missing from recovery"
      assert Map.has_key?(entries, {2, 0}), "obj 2 missing from recovery"
      assert Map.has_key?(entries, {3, 0}), "obj 3 missing from recovery"
      assert Map.has_key?(entries, {4, 0}), "obj 4 missing from recovery"
      assert Map.has_key?(entries, {5, 0}), "obj 5 missing from recovery"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4 — R-4: Catalog / Pages Tree Fallback (tasks 4.1–4.4 RED)
  #
  # Spec citations:
  #   § 7.7.2 — Document catalog
  #   § 7.7.3 — Page tree
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Fixture: PDF with NO /Root key in the trailer dict.
  # The catalog object (Type Catalog) exists in the body and can be found via
  # xref scan, but the trailer dict deliberately omits /Root so that
  # Page.list_refs/1 cannot resolve the catalog directly.
  #
  # Object layout:
  #   1 0 obj — catalog   (Type Catalog, Pages 2 0 R)
  #   2 0 obj — pages     (Type Pages, Kids [3 0 R], Count 1)
  #   3 0 obj — page      (Type Page, Parent 2 0 R, MediaBox, Contents 4 0 R)
  #   4 0 obj — content   ("BT /F1 12 Tf (Hello) Tj ET")
  #   5 0 obj — font      (Type Font, Subtype Type1, BaseFont Helvetica)
  # Trailer: /Size 6 but NO /Root entry.
  defp build_no_root_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 5 0 R>>>> /Contents 4 0 R>>\nendobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj4 = "4 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    obj5_offset = obj4_offset + byte_size(obj4)

    obj5 =
      "5 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    # Deliberately NO /Root in trailer
    trailer = "trailer\n<</Size 6>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # Fixture: PDF where /Root resolves (Catalog object exists) but /Pages is a
  # dangling reference (obj 99 does not exist in xref).
  #
  # Object layout:
  #   1 0 obj — catalog   (Type Catalog, Pages 99 0 R — DANGLING)
  #   2 0 obj — page      (Type Page, Parent 1 0 R, MediaBox, Contents 3 0 R)
  #   3 0 obj — content   ("BT /F1 12 Tf (Hello) Tj ET")
  #   4 0 obj — font      (Type Font, Subtype Type1, BaseFont Helvetica)
  # Trailer: /Root 1 0 R but catalog's /Pages → 99 0 R which is absent.
  defp build_dangling_pages_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    # Catalog exists but /Pages points to non-existent obj 99
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 99 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    # Page has /Parent and /Contents so it passes the filter
    obj2 =
      "2 0 obj\n<</Type /Page /Parent 1 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 3 0 R>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj3 = "3 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    xref_offset = obj4_offset + byte_size(obj4)

    xref =
      "xref\n0 5\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n"

    # obj 99 deliberately absent from xref
    trailer = "trailer\n<</Size 5 /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # Fixture: PDF with one Form XObject stream AND one real page.
  # The Form XObject has /Type /XObject /Subtype /Form but lacks /Contents and
  # /Parent — so the catalog-fallback scan MUST filter it out.
  #
  # Object layout:
  #   1 0 obj — catalog   (Type Catalog, Pages 99 0 R — DANGLING, triggers fallback)
  #   2 0 obj — page      (Type Page, Parent 1 0 R, Contents 3 0 R)  ← REAL PAGE
  #   3 0 obj — content   stream for page
  #   4 0 obj — font
  #   5 0 obj — Form XObject  (Type XObject, Subtype Form — NO /Contents, NO /Parent)
  defp build_form_xobject_pdf do
    header = "%PDF-1.4\n"

    obj1_offset = byte_size(header)
    # Catalog with dangling /Pages to trigger catalog-fallback
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 99 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    # Real page: has /Type /Page AND /Parent AND /Contents
    obj2 =
      "2 0 obj\n<</Type /Page /Parent 1 0 R /MediaBox [0 0 612 792]\n" <>
        "/Resources <</Font <</F1 4 0 R>>>> /Contents 3 0 R>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)
    content = "BT /F1 12 Tf 100 700 Td (Hello) Tj ET"
    obj3 = "3 0 obj\n<</Length #{byte_size(content)}>>\nstream\n#{content}\nendstream\nendobj\n"

    obj4_offset = obj3_offset + byte_size(obj3)

    obj4 =
      "4 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    # Form XObject: /Type /XObject /Subtype /Form — deliberately NO /Parent, NO /Contents
    obj5_offset = obj4_offset + byte_size(obj4)
    form_content = "q Q"

    obj5 =
      "5 0 obj\n<</Type /XObject /Subtype /Form /Length #{byte_size(form_content)}>>\n" <>
        "stream\n#{form_content}\nendstream\nendobj\n"

    xref_offset = obj5_offset + byte_size(obj5)

    xref =
      "xref\n0 6\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n"

    # obj 99 absent — dangling /Pages triggers catalog fallback
    trailer = "trailer\n<</Size 6 /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj4 <> obj5 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # Fixture: PDF with a valid /Pages tree but one bad /Kid ref among 3 good kids.
  # Object layout:
  #   1 0 obj — catalog   (Type Catalog, Pages 2 0 R)
  #   2 0 obj — pages     (Type Pages, Kids [3 0 R, 99 0 R, 5 0 R], Count 3)
  #   3 0 obj — page 1    (Type Page, Contents 6 0 R)
  #   4 0 obj — (unused — offset placeholder) → Actually obj 4 = content for page 1
  #   5 0 obj — page 3    (Type Page, Contents 7 0 R)
  #   6 0 obj — content 1
  #   7 0 obj — content 3
  #   8 0 obj — font
  # obj 99 is NOT in xref — walking it as a kid should produce {:page_failed, _, _}
  defp build_bad_kid_ref_pdf do
    header = "%PDF-1.4\n"

    font_res = "/Resources <</Font <</F1 8 0 R>>>>"

    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    obj2_offset = obj1_offset + byte_size(obj1)
    # Kids: [3 0 R, 99 0 R (bad), 5 0 R] — Count 3
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 99 0 R 5 0 R] /Count 3>>\nendobj\n"

    obj3_offset = obj2_offset + byte_size(obj2)

    obj3 =
      "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
        font_res <> " /Contents 6 0 R>>\nendobj\n"

    obj5_offset = obj3_offset + byte_size(obj3)

    obj5 =
      "5 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
        font_res <> " /Contents 7 0 R>>\nendobj\n"

    obj6_offset = obj5_offset + byte_size(obj5)
    content1 = "BT /F1 12 Tf 100 700 Td (Page1) Tj ET"
    obj6 = "6 0 obj\n<</Length #{byte_size(content1)}>>\nstream\n#{content1}\nendstream\nendobj\n"

    obj7_offset = obj6_offset + byte_size(obj6)
    content3 = "BT /F1 12 Tf 100 700 Td (Page3) Tj ET"
    obj7 = "7 0 obj\n<</Length #{byte_size(content3)}>>\nstream\n#{content3}\nendstream\nendobj\n"

    obj8_offset = obj7_offset + byte_size(obj7)

    obj8 =
      "8 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    xref_offset = obj8_offset + byte_size(obj8)

    xref =
      "xref\n0 9\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        # obj 4 — placeholder (we use non-contiguous obj numbers: 3, 5, 6, 7, 8)
        # We need 9 xref entries (0-8); obj 4 is unused, set offset same as obj 3 but marked free
        "0000000000 00001 f\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n" <>
        pad_offset(obj7_offset) <> " 00000 n\r\n" <>
        pad_offset(obj8_offset) <> " 00000 n\r\n"

    # obj 99 absent — walking it as a kid triggers lenient skip
    trailer = "trailer\n<</Size 9 /Root 1 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> obj2 <> obj3 <> obj5 <> obj6 <> obj7 <> obj8 <> xref <> trailer
  end

  # ---------------------------------------------------------------------------
  # 4.1 RED — PDF with NO /Root in trailer
  # ---------------------------------------------------------------------------

  describe "R-4: catalog/pages tree fallback — no /Root in trailer" do
    test "recover: true — no /Root returns {:ok, doc} with page_count and page_tree_recovered in log" do
      bin = build_no_root_pdf()
      result = Pdf.Reader.open(bin, recover: true)

      assert match?({:ok, _}, result),
             "Expected {:ok, doc}, got: #{inspect(result)}"

      {:ok, doc} = result
      {:ok, count} = Pdf.Reader.page_count(doc)
      assert count >= 1, "Expected page count >= 1 after catalog fallback, got: #{count}"

      log = Pdf.Reader.recovery_log(doc)

      page_tree_events = Enum.filter(log, &match?({:page_tree_recovered, _}, &1))

      assert length(page_tree_events) >= 1,
             "Expected {:page_tree_recovered, _} in log, got: #{inspect(log)}"
    end

    test "recover: false (strict) — no /Root returns {:error, _}" do
      bin = build_no_root_pdf()
      result = Pdf.Reader.open(bin)

      # In strict mode, absent /Root must cause an error
      assert match?({:error, _}, result) or
               (match?({:ok, _}, result) and
                  match?({:error, _}, Pdf.Reader.page_count(elem(result, 1)))),
             "Expected an error for missing /Root in strict mode, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # 4.2 RED — PDF where /Root resolves but /Pages is a dangling ref
  # ---------------------------------------------------------------------------

  describe "R-4: catalog/pages tree fallback — dangling /Pages ref" do
    test "recover: true — dangling /Pages returns {:ok, doc} with page_tree_recovered in log" do
      bin = build_dangling_pages_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)

      {:ok, count} = Pdf.Reader.page_count(doc)
      assert count >= 1, "Expected page count >= 1 after pages-tree fallback, got: #{count}"

      log = Pdf.Reader.recovery_log(doc)
      page_tree_events = Enum.filter(log, &match?({:page_tree_recovered, _}, &1))

      assert length(page_tree_events) >= 1,
             "Expected {:page_tree_recovered, _} in log, got: #{inspect(log)}"
    end

    # Triangulation: strict mode on the same fixture must fail (non-trivial page tree)
    test "recover: false (strict) — dangling /Pages returns an error" do
      bin = build_dangling_pages_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.page_count(doc)

      assert match?({:error, _}, result),
             "Expected {:error, _} in strict mode for dangling /Pages, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # 4.3 RED — Form XObject must be filtered out of the catalog-fallback scan
  # ---------------------------------------------------------------------------

  describe "R-4: catalog/pages tree fallback — Form XObject filtered out" do
    test "recover: true — Form XObject is NOT counted as a page; exactly 1 real page found" do
      bin = build_form_xobject_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)

      {:ok, count} = Pdf.Reader.page_count(doc)

      assert count == 1,
             "Expected exactly 1 page (Form XObject must be filtered), got: #{count}"

      log = Pdf.Reader.recovery_log(doc)
      page_tree_events = Enum.filter(log, &match?({:page_tree_recovered, _}, &1))

      assert length(page_tree_events) >= 1,
             "Expected {:page_tree_recovered, _} in log, got: #{inspect(log)}"
    end

    # Triangulation: a valid PDF (no dangling /Pages) does NOT trigger the fallback
    test "recover: true — well-formed PDF uses normal tree walk (no page_tree_recovered event)" do
      bin = build_minimal_valid_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)

      log = Pdf.Reader.recovery_log(doc)
      page_tree_events = Enum.filter(log, &match?({:page_tree_recovered, _}, &1))

      assert page_tree_events == [],
             "Expected NO {:page_tree_recovered, _} for well-formed PDF, got: #{inspect(log)}"

      {:ok, count} = Pdf.Reader.page_count(doc)
      assert count == 1, "Expected 1 page in valid PDF, got: #{count}"
    end
  end

  # ---------------------------------------------------------------------------
  # 4.4 RED — /Kids with one bad ref among 3 good ones
  # ---------------------------------------------------------------------------

  describe "R-4: lenient kid traversal — one bad kid ref among good ones" do
    test "recover: true — 3 good kids succeed, bad kid is logged as {:page_failed, _, _}" do
      bin = build_bad_kid_ref_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)
      {:ok, texts, updated_doc} = Pdf.Reader.read_text(doc)

      # At least 2 pages should have text (pages 1 and 3 are good)
      assert length(texts) >= 2,
             "Expected at least 2 text pages, got #{length(texts)}: #{inspect(texts)}"

      log = Pdf.Reader.recovery_log(updated_doc)
      page_failed_events = Enum.filter(log, &match?({:page_failed, _, _}, &1))

      assert length(page_failed_events) >= 1,
             "Expected at least one {:page_failed, _, _} in log, got: #{inspect(log)}"
    end

    # Triangulation: strict mode halts on the bad kid ref — no partial results
    test "recover: false (strict) — bad kid ref halts tree walk with {:error, _}" do
      bin = build_bad_kid_ref_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_text(doc)

      assert match?({:error, _}, result),
             "Expected {:error, _} in strict mode with bad kid ref, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 2 — R-2: Font decoder lenience (tasks 2.4 + 2.5)
  #
  # Spec citations:
  #   § 9.6   — Font dictionaries
  #   § 9.10  — Extraction of text content
  # ---------------------------------------------------------------------------

  describe "R-2: font decoder lenience — recover mode" do
    # 2.4 RED: bad font ref → fallback U+FFFD decoder; text valid UTF-8; recovery_log has event
    test "recover: true — bad font ref produces valid UTF-8 text and logs {:font_skipped, _, _, _}" do
      bin = build_bad_font_ref_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)
      {:ok, texts, updated_doc} = Pdf.Reader.read_text(doc)

      # Some text should be returned (replacement chars are ok)
      all_text = Enum.join(texts, " ")
      assert String.valid?(all_text), "Expected valid UTF-8 text, got invalid: #{inspect(all_text)}"

      log = Pdf.Reader.recovery_log(updated_doc)

      font_skipped_events =
        Enum.filter(log, fn
          {:font_skipped, _, _, _} -> true
          _ -> false
        end)

      assert length(font_skipped_events) >= 1,
             "Expected {:font_skipped, _, _, _} in log, got: #{inspect(log)}"
    end

    # 2.5 RED: strict mode returns {:error, _} or propagates exception on bad font
    test "recover: false (strict) — bad font ref returns {:error, _}" do
      bin = build_bad_font_ref_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_text(doc)

      # In strict mode a font resolution failure must abort
      assert match?({:error, _}, result),
             "Expected {:error, _} in strict mode on bad font, got: #{inspect(result)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 5 — Integration tests
  #
  # 5.2 SMOKE: every valid fixture opened with recover: true produces an empty
  #           recovery_log (no spurious recovery events on well-formed PDFs).
  #
  # 5.3 SMOKE: rfc.pdf opened with recover: true — text extraction unchanged
  #           and recovery_log is empty.
  #
  # 5.4 STRESS: composite PDF with (a) corrupted xref, (b) truncated page
  #             content stream, (c) bad font ref. All three recovery event
  #             types must appear in the recovery_log.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # 5.2 — Sweep: every fixture PDF opened with recover: true must have empty log
  # ---------------------------------------------------------------------------

  describe "Phase 5.2 — recover: true produces empty log on valid PDFs" do
    @describetag :fixtures

    test "all fixture PDFs produce empty recovery_log when opened with recover: true" do
      fixtures_dir = Path.join(__DIR__, "../../fixtures/pdfs")

      # Collect all .pdf files (non-recursive for now; encrypted sub-dir is skipped)
      pdf_files =
        fixtures_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".pdf"))
        |> Enum.map(&Path.join(fixtures_dir, &1))

      assert pdf_files != [],
             "Expected at least one PDF fixture in #{fixtures_dir}"

      for path <- pdf_files do
        result = Pdf.Reader.open(path, recover: true)

        case result do
          {:ok, doc} ->
            log = Pdf.Reader.recovery_log(doc)

            assert log == [],
                   "Expected empty recovery_log for #{Path.basename(path)}, got: #{inspect(log)}"

          {:error, reason} when reason in [
            :encrypted_password_required,
            :encrypted_wrong_password,
            :encrypted_unsupported_handler
          ] ->
            # Encrypted PDFs cannot be opened without a password — skip them
            :ok

          {:error, reason} ->
            flunk("Expected {:ok, doc} for #{Path.basename(path)}, got {:error, #{inspect(reason)}}")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5.3 — Smoke: rfc.pdf with recover: true — text unchanged, empty log
  # ---------------------------------------------------------------------------

  describe "Phase 5.3 — rfc.pdf smoke test with recover: true" do
    @describetag :fixtures

    test "rfc.pdf opened with recover: true produces empty log and extractable text" do
      rfc_path = Path.join(__DIR__, "../../fixtures/pdfs/rfc.pdf")

      # Open in strict mode first to get the baseline text
      {:ok, strict_doc} = Pdf.Reader.open(rfc_path)
      {:ok, strict_texts, _} = Pdf.Reader.read_text(strict_doc)

      # Open in recover mode
      {:ok, recover_doc} = Pdf.Reader.open(rfc_path, recover: true)
      log = Pdf.Reader.recovery_log(recover_doc)

      assert log == [],
             "Expected empty recovery_log for rfc.pdf, got: #{inspect(log)}"

      {:ok, recover_texts, _} = Pdf.Reader.read_text(recover_doc)

      # Text extraction must be equivalent between strict and recover modes
      assert recover_texts == strict_texts,
             "Text extraction differs between strict and recover modes for rfc.pdf"
    end
  end

  # ---------------------------------------------------------------------------
  # 5.4 — Stress: composite PDF with corrupted xref + truncated page + bad font
  #
  # This fixture combines three faults:
  #   (a) startxref points to garbage offset 999999 → triggers R-3 (xref_recovered)
  #   (b) page 2 /Contents → missing obj 98 → triggers R-1 (page_failed)
  #   (c) page 3 /Font /F1 → missing obj 97 → triggers R-2 (font_skipped)
  #
  # All three recovery event types must appear in the union of recovery_log
  # entries from open/2 + read_text/1.
  # ---------------------------------------------------------------------------

  defp build_composite_stress_pdf do
    header = "%PDF-1.4\n"

    font_res_good = "/Resources <</Font <</F1 8 0 R>>>>"
    # Page 3 references font obj 97 — does NOT exist
    font_res_bad = "/Resources <</Font <</F1 97 0 R>>>>"

    # obj 1 — catalog
    obj1_offset = byte_size(header)
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"

    # obj 2 — pages (3 pages)
    obj2_offset = obj1_offset + byte_size(obj1)
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 5 0 R 6 0 R] /Count 3>>\nendobj\n"

    # obj 3 — page 1 (good)
    obj3_offset = obj2_offset + byte_size(obj2)
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
           font_res_good <> " /Contents 4 0 R>>\nendobj\n"

    # obj 4 — content for page 1 (good)
    obj4_offset = obj3_offset + byte_size(obj3)
    content1 = "BT /F1 12 Tf 100 700 Td (Page1) Tj ET"
    obj4 = "4 0 obj\n<</Length #{byte_size(content1)}>>\nstream\n#{content1}\nendstream\nendobj\n"

    # obj 5 — page 2 (Contents → obj 98 which does NOT exist → R-1 page_failed)
    obj5_offset = obj4_offset + byte_size(obj4)
    obj5 = "5 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
           font_res_good <> " /Contents 98 0 R>>\nendobj\n"

    # obj 6 — page 3 (Font → obj 97 which does NOT exist → R-2 font_skipped)
    obj6_offset = obj5_offset + byte_size(obj5)
    obj6 = "6 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " <>
           font_res_bad <> " /Contents 7 0 R>>\nendobj\n"

    # obj 7 — content for page 3 (good)
    obj7_offset = obj6_offset + byte_size(obj6)
    content3 = "BT /F1 12 Tf 100 700 Td (Page3) Tj ET"
    obj7 = "7 0 obj\n<</Length #{byte_size(content3)}>>\nstream\n#{content3}\nendstream\nendobj\n"

    # obj 8 — font (good)
    obj8_offset = obj7_offset + byte_size(obj7)
    obj8 = "8 0 obj\n<</Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding>>\nendobj\n"

    # (a) xref is present but trailer uses startxref 999999 — forces R-3 linear scan
    _xref_offset = obj8_offset + byte_size(obj8)

    xref =
      "xref\n0 9\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n" <>
        pad_offset(obj2_offset) <> " 00000 n\r\n" <>
        pad_offset(obj3_offset) <> " 00000 n\r\n" <>
        pad_offset(obj4_offset) <> " 00000 n\r\n" <>
        pad_offset(obj5_offset) <> " 00000 n\r\n" <>
        pad_offset(obj6_offset) <> " 00000 n\r\n" <>
        pad_offset(obj7_offset) <> " 00000 n\r\n" <>
        pad_offset(obj8_offset) <> " 00000 n\r\n"

    # Deliberately wrong startxref to force linear scan (R-3)
    trailer_str = "trailer\n<</Size 9 /Root 1 0 R>>\nstartxref\n999999\n%%EOF\n"

    header <>
      obj1 <>
      obj2 <>
      obj3 <>
      obj4 <>
      obj5 <>
      obj6 <>
      obj7 <>
      obj8 <>
      xref <>
      trailer_str
  end

  describe "Phase 5.4 — composite stress test: corrupted xref + truncated page + bad font" do
    test "recover: true — all three recovery event types present in the union log" do
      bin = build_composite_stress_pdf()
      {:ok, doc} = Pdf.Reader.open(bin, recover: true)
      {:ok, _texts, updated_doc} = Pdf.Reader.read_text(doc)

      # Collect the full recovery_log from both open/2 and read_text/1
      log = Pdf.Reader.recovery_log(updated_doc)

      # (a) R-3: xref_recovered must be present (corrupted startxref offset)
      xref_events = Enum.filter(log, &match?({:xref_recovered, _}, &1))
      assert length(xref_events) >= 1,
             "Expected {:xref_recovered, _} in log — R-3 not triggered. Log: #{inspect(log)}"

      # (b) R-1: page_failed must be present (page 2 /Contents → missing obj 98)
      page_failed_events = Enum.filter(log, &match?({:page_failed, _, _}, &1))
      assert length(page_failed_events) >= 1,
             "Expected {:page_failed, _, _} in log — R-1 not triggered. Log: #{inspect(log)}"

      # (c) R-2: font_skipped must be present (page 3 font → missing obj 97)
      font_skipped_events = Enum.filter(log, &match?({:font_skipped, _, _, _}, &1))
      assert length(font_skipped_events) >= 1,
             "Expected {:font_skipped, _, _, _} in log — R-2 not triggered. Log: #{inspect(log)}"
    end
  end

  # Spec scenarios — Fatal Errors Remain Fatal (W-2 from verify report).
  # PDF 1.7 § 7.5: even when recovery is requested, a non-PDF binary MUST
  # still be rejected at the header check, and encrypted PDFs MUST still
  # surface the encryption gate. Recovery is for malformed-but-valid PDFs only.
  describe "Fatal errors remain fatal under recover: true" do
    test "recover: true — non-PDF binary still returns {:error, :not_a_pdf}" do
      assert {:error, :not_a_pdf} = Pdf.Reader.open("definitely not a pdf", recover: true)
    end

    @tag :fixtures
    test "recover: true — encrypted PDF still requires password flow" do
      path =
        Path.join([__DIR__, "..", "..", "fixtures", "pdfs", "encrypted", "rc4_v2_user.pdf"])

      if File.exists?(path) do
        bin = File.read!(path)
        # No password — must still surface the encryption gate, not silently recover.
        result = Pdf.Reader.open(bin, recover: true)

        assert match?({:error, :encrypted_password_required}, result) or
                 match?({:error, :encrypted_wrong_password}, result),
               "Expected encryption error, got: #{inspect(result)}"
      end
    end
  end
end
