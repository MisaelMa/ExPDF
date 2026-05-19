defmodule Pdf.Reader.AnnotationsTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Annotations

  # ---------------------------------------------------------------------------
  # PDF Builder helpers — same build_pdf/4 + pad_offset/1 pattern as
  # destination_test.exs and acroform_test.exs
  # ---------------------------------------------------------------------------

  defp build_pdf(objects, header, size, root_ref) do
    offsets =
      Enum.reduce(objects, {byte_size(header), []}, fn obj, {offset, acc} ->
        {offset + byte_size(obj), [offset | acc]}
      end)
      |> then(fn {_final, reversed} -> Enum.reverse(reversed) end)

    body = Enum.join(objects)
    xref_offset = byte_size(header) + byte_size(body)
    xref_count = length(objects) + 1

    xref_entries =
      Enum.map_join(Enum.zip(1..length(objects), offsets), fn {_n, offset} ->
        pad_offset(offset) <> " 00000 n\r\n"
      end)

    xref =
      "xref\n" <>
        "0 #{xref_count}\n" <>
        "0000000000 65535 f\r\n" <>
        xref_entries

    trailer =
      "trailer\n" <>
        "<</Size #{size} /Root #{root_ref}>>\n" <>
        "startxref\n" <>
        "#{xref_offset}\n" <>
        "%%EOF\n"

    header <> body <> xref <> trailer
  end

  defp pad_offset(n) do
    n |> Integer.to_string() |> String.pad_leading(10, "0")
  end

  defp open_doc(bin) do
    {:ok, doc} = Pdf.Reader.open(bin)
    doc
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — no annotations on any page
  # Object layout:
  #   1 0 R — Catalog
  #   2 0 R — Pages root (1 kid)
  #   3 0 R — Page 1 (no /Annots)
  # ---------------------------------------------------------------------------

  defp craft_no_annots_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"

    build_pdf([obj1, obj2, obj3], header, 4, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — single Link annotation with /URI action
  #
  # Object layout:
  #   1 0 R — Catalog
  #   2 0 R — Pages root (1 kid)
  #   3 0 R — Page 1 (with /Annots [4 0 R])
  #   4 0 R — Link annotation with /A /S /URI
  # ---------------------------------------------------------------------------

  defp craft_link_uri_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\nendobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Link /Rect [10 20 200 40]\n" <>
        "  /A <</S /URI /URI (https://example.com)>>>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — single Link annotation with /Dest array
  #
  # Object layout:
  #   1 0 R — Catalog
  #   2 0 R — Pages root (2 kids)
  #   3 0 R — Page 1
  #   4 0 R — Page 2
  #   5 0 R — Page 1 with /Annots [6 0 R]
  #   6 0 R — Link annotation with /Dest [3 0 R /XYZ ...]
  #
  # NOTE: Page 1 has the annotation, /Dest points to page 1 (obj 3)
  # ---------------------------------------------------------------------------

  defp craft_link_dest_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\nendobj\n"
    # Page 1 — has annotation
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [5 0 R]>>\n" <>
        "endobj\n"

    # Page 2 — no annotations
    obj4 = "4 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"

    # Link annotation on page 1 pointing to page 2 (obj 4)
    obj5 =
      "5 0 obj\n" <>
        "<</Type /Annot /Subtype /Link /Rect [50 100 300 120]\n" <>
        "  /Dest [4 0 R /XYZ 0 0 0]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — Link with /A /S /GoTo /D array
  # ---------------------------------------------------------------------------

  defp craft_link_goto_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [5 0 R]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"

    # Link with /A GoTo pointing to page 2
    obj5 =
      "5 0 obj\n" <>
        "<</Type /Annot /Subtype /Link /Rect [0 0 100 100]\n" <>
        "  /A <</S /GoTo /D [4 0 R /XYZ 0 0 0]>>>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — Highlight annotation with /QuadPoints
  # ---------------------------------------------------------------------------

  defp craft_highlight_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Highlight /Rect [10 20 200 40]\n" <>
        "  /QuadPoints [10 40 200 40 10 20 200 20]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — FileAttachment annotation with /FS /EF /F stream ref
  # ---------------------------------------------------------------------------

  defp craft_file_attachment_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    # FileAttachment with /FS dict containing /EF /F ref
    # Embedded file stream at obj 5
    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /FileAttachment /Rect [100 200 150 250]\n" <>
        "  /FS <</Type /Filespec /F (attachment.txt) /EF <</F 5 0 R>>>>>>\n" <>
        "endobj\n"

    obj5 =
      "5 0 obj\n" <>
        "<</Type /EmbeddedFile /Length 0>>\n" <>
        "stream\nendstream\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — Text annotation with /Contents and /T
  # ---------------------------------------------------------------------------

  defp craft_text_annot_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Text /Rect [50 60 70 80]\n" <>
        "  /Contents (A note here) /T (Author Name)>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — Text annotation with UTF-16BE BOM in /Contents
  # ---------------------------------------------------------------------------

  defp craft_utf16_contents_pdf do
    header = "%PDF-1.4\n"

    # UTF-16BE encoding of "Hi" = <<0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69>>
    # In PDF hex string: <FEFF00480069>
    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Text /Rect [0 0 50 50]\n" <>
        "  /Contents <FEFF00480069>>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — Unknown subtype /Redact
  # ---------------------------------------------------------------------------

  defp craft_unknown_subtype_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Redact /Rect [0 0 200 100] /Contents (redacted)>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — 3 pages, annotations on page 1 and page 3
  # ---------------------------------------------------------------------------

  defp craft_multi_page_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3>>\nendobj\n"

    # Page 1 — has annotation at obj 6
    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [6 0 R]>>\n" <>
        "endobj\n"

    # Page 2 — no annotations
    obj4 = "4 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"

    # Page 3 — has annotation at obj 7
    obj5 =
      "5 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [7 0 R]>>\n" <>
        "endobj\n"

    # Annotation on page 1
    obj6 =
      "6 0 obj\n" <>
        "<</Type /Annot /Subtype /Text /Rect [10 10 50 50] /Contents (Page 1 note)>>\n" <>
        "endobj\n"

    # Annotation on page 3
    obj7 =
      "7 0 obj\n" <>
        "<</Type /Annot /Subtype /Text /Rect [20 20 60 60] /Contents (Page 3 note)>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7], header, 8, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — multiple subtype atoms (Underline, StrikeOut, Squiggly, Square, Circle, FreeText)
  # ---------------------------------------------------------------------------

  defp craft_multi_subtype_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]\n" <>
        "  /Annots [4 0 R 5 0 R 6 0 R 7 0 R 8 0 R 9 0 R]>>\n" <>
        "endobj\n"

    obj4 = "4 0 obj\n<</Type /Annot /Subtype /Underline /Rect [0 0 100 10]>>\nendobj\n"
    obj5 = "5 0 obj\n<</Type /Annot /Subtype /StrikeOut /Rect [0 0 100 10]>>\nendobj\n"
    obj6 = "6 0 obj\n<</Type /Annot /Subtype /Squiggly /Rect [0 0 100 10]>>\nendobj\n"
    obj7 = "7 0 obj\n<</Type /Annot /Subtype /Square /Rect [0 0 100 100]>>\nendobj\n"
    obj8 = "8 0 obj\n<</Type /Annot /Subtype /Circle /Rect [0 0 100 100]>>\nendobj\n"
    obj9 = "9 0 obj\n<</Type /Annot /Subtype /FreeText /Rect [0 0 200 100]>>\nendobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5, obj6, obj7, obj8, obj9], header, 10, "1 0 R")
  end

  # ---------------------------------------------------------------------------
  # PDF fixture — annotation with /Rect for rect parsing test
  # ---------------------------------------------------------------------------

  defp craft_rect_annot_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Text /Rect [10 20 300 400]>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # ===========================================================================
  # Task 5.7 — no /Annots on any page → {:ok, [], doc}
  # Spec: R-AO2, S-AO18
  # ===========================================================================

  describe "Annotations.read/1 — empty PDF (no annotations)" do
    @tag :integration
    test "5.7: PDF with no /Annots on any page returns {:ok, [], doc}" do
      doc = open_doc(craft_no_annots_pdf())
      assert {:ok, [], _doc} = Annotations.read(doc)
    end
  end

  # ===========================================================================
  # Task 5.1 — Link with /URI action
  # Spec: R-AO14, R-AO15, R-AO20, S-AO11
  # ===========================================================================

  describe "Annotations.read/1 — Link with /URI" do
    @tag :integration
    test "5.1: Link with /A /S /URI → :url populated, :dest_page nil, :type :link" do
      doc = open_doc(craft_link_uri_pdf())
      assert {:ok, annotations, _doc} = Annotations.read(doc)
      assert length(annotations) == 1

      [annot] = annotations
      assert annot.type == :link
      assert annot.url == "https://example.com"
      assert annot.dest_page == nil
      assert annot.page == 1
    end
  end

  # ===========================================================================
  # Task 5.2 — Link with /Dest array → :dest_page N, :url nil
  # Spec: R-AO14, R-AO15, R-AO21, S-AO12
  # ===========================================================================

  describe "Annotations.read/1 — Link with /Dest array" do
    @tag :integration
    test "5.2: Link with /Dest [4 0 R /XYZ] → :dest_page 2, :url nil" do
      doc = open_doc(craft_link_dest_pdf())
      assert {:ok, annotations, _doc} = Annotations.read(doc)
      assert length(annotations) == 1

      [annot] = annotations
      assert annot.type == :link
      assert annot.dest_page == 2
      assert annot.url == nil
    end
  end

  # ===========================================================================
  # Task 5.3 (original task 5.4 in user prompt) — Link with /A /S /GoTo /D
  # Spec: R-AO14, R-AO15, R-AO21
  # ===========================================================================

  describe "Annotations.read/1 — Link with /A /S /GoTo /D array" do
    @tag :integration
    test "5.3: Link with /A GoTo /D array → :dest_page resolved, :url nil" do
      doc = open_doc(craft_link_goto_pdf())
      assert {:ok, annotations, _doc} = Annotations.read(doc)
      assert length(annotations) == 1

      [annot] = annotations
      assert annot.type == :link
      assert annot.dest_page == 2
      assert annot.url == nil
    end
  end

  # ===========================================================================
  # Task 5.3 (in tasks list) — Highlight with /QuadPoints
  # Spec: R-AO23, S-AO13
  # ===========================================================================

  describe "Annotations.read/1 — Highlight with /QuadPoints" do
    @tag :integration
    test "5.3b: Highlight with 8 QuadPoints → :kind_specific[:quad_points] has 1 tuple" do
      doc = open_doc(craft_highlight_pdf())
      assert {:ok, [annot], _doc} = Annotations.read(doc)

      assert annot.type == :highlight
      assert %{quad_points: qp} = annot.kind_specific
      assert length(qp) == 1
      # Each tuple should have 8 elements
      assert tuple_size(hd(qp)) == 8
      assert hd(qp) == {10.0, 40.0, 200.0, 40.0, 10.0, 20.0, 200.0, 20.0}
    end
  end

  # ===========================================================================
  # Task 5.4 — FileAttachment :embedded_file_ref
  # Spec: R-AO22, S-AO14
  # ===========================================================================

  describe "Annotations.read/1 — FileAttachment" do
    @tag :integration
    test "5.4: FileAttachment with /FS /EF /F 5 0 R → :embedded_file_ref {:ref, 5, 0}" do
      doc = open_doc(craft_file_attachment_pdf())
      assert {:ok, [annot], _doc} = Annotations.read(doc)

      assert annot.type == :file_attachment
      assert annot.embedded_file_ref == {:ref, 5, 0}
    end
  end

  # ===========================================================================
  # Task 5.5 — Text annotation :contents + :title decoded via Utils
  # Spec: R-AO19, S-AO15
  # ===========================================================================

  describe "Annotations.read/1 — Text annotation with /Contents and /T" do
    @tag :integration
    test "5.5: Text annotation → :contents and :title decoded" do
      doc = open_doc(craft_text_annot_pdf())
      assert {:ok, [annot], _doc} = Annotations.read(doc)

      assert annot.type == :text
      assert annot.contents == "A note here"
      assert annot.title == "Author Name"
    end
  end

  # ===========================================================================
  # Task 5.8 — UTF-16BE BOM in /Contents decoded
  # Spec: R-AO19
  # ===========================================================================

  describe "Annotations.read/1 — UTF-16BE BOM in /Contents" do
    @tag :integration
    test "5.8: UTF-16BE BOM in /Contents → decoded to UTF-8 string" do
      doc = open_doc(craft_utf16_contents_pdf())
      assert {:ok, [annot], _doc} = Annotations.read(doc)

      assert annot.contents == "Hi"
    end
  end

  # ===========================================================================
  # Task 5.6 — Unknown subtype → :type :unknown, :kind_specific preserves raw
  # Spec: R-AO16, S-AO16
  # ===========================================================================

  describe "Annotations.read/1 — unknown subtype" do
    @tag :integration
    test "5.6: /Subtype /Redact → :type :unknown, :kind_specific is non-empty map with raw fields" do
      doc = open_doc(craft_unknown_subtype_pdf())
      assert {:ok, [annot], _doc} = Annotations.read(doc)

      assert annot.type == :unknown
      assert is_map(annot.kind_specific)
      assert map_size(annot.kind_specific) > 0
      # The raw dict should contain /Subtype
      assert Map.has_key?(annot.kind_specific, "Subtype")
    end
  end

  # ===========================================================================
  # Task 5.8b (task 5.10 in original list) — Multi-page with annotations
  # Spec: R-AO17
  # ===========================================================================

  describe "Annotations.read/1 — multi-page :page index" do
    @tag :integration
    test "5.10: annotations on page 1 and page 3 have correct :page values (1-indexed)" do
      doc = open_doc(craft_multi_page_pdf())
      assert {:ok, annotations, _doc} = Annotations.read(doc)

      assert length(annotations) == 2

      pages = annotations |> Enum.map(& &1.page) |> Enum.sort()
      assert pages == [1, 3]
    end
  end

  # ===========================================================================
  # Task 5.9 — :rect parsed to {x1, y1, x2, y2} tuple
  # Spec: R-AO18
  # ===========================================================================

  describe "Annotations.read/1 — :rect parsing" do
    @tag :integration
    test "5.9: annotation /Rect [10 20 300 400] → :rect {10.0, 20.0, 300.0, 400.0}" do
      doc = open_doc(craft_rect_annot_pdf())
      assert {:ok, [annot], _doc} = Annotations.read(doc)

      assert annot.rect == {10.0, 20.0, 300.0, 400.0}
    end
  end

  # ===========================================================================
  # Task 5.10 — remaining 6 subtypes (Underline, StrikeOut, Squiggly, Square, Circle, FreeText)
  # Spec: R-AO15
  # ===========================================================================

  describe "Annotations.read/1 — remaining subtype atoms" do
    @tag :integration
    test "5.10b: Underline, StrikeOut, Squiggly, Square, Circle, FreeText have correct :type atoms" do
      doc = open_doc(craft_multi_subtype_pdf())
      assert {:ok, annotations, _doc} = Annotations.read(doc)

      assert length(annotations) == 6

      types = annotations |> Enum.map(& &1.type) |> MapSet.new()
      assert MapSet.member?(types, :underline)
      assert MapSet.member?(types, :strikeout)
      assert MapSet.member?(types, :squiggly)
      assert MapSet.member?(types, :square)
      assert MapSet.member?(types, :circle)
      assert MapSet.member?(types, :freetext)
    end
  end
end
