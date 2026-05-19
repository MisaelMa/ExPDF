defmodule Pdf.Reader.ReaderAnnotationsTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Annotation

  # ---------------------------------------------------------------------------
  # PDF fixture builders — minimal hand-crafted PDFs for delegation tests.
  # Same build_pdf/4 + pad_offset/1 pattern as annotations_test.exs.
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

  # Minimal PDF with a Text annotation
  defp craft_annotation_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"

    obj3 =
      "3 0 obj\n" <>
        "<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R]>>\n" <>
        "endobj\n"

    obj4 =
      "4 0 obj\n" <>
        "<</Type /Annot /Subtype /Text /Rect [10 10 100 100] /Contents (Hello)>>\n" <>
        "endobj\n"

    build_pdf([obj1, obj2, obj3, obj4], header, 5, "1 0 R")
  end

  # Minimal PDF with no annotations
  defp craft_no_annotation_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"

    build_pdf([obj1, obj2, obj3], header, 4, "1 0 R")
  end

  # ===========================================================================
  # Task 6.3 — Pdf.Reader.read_annotations/1 happy-path delegation (R-AO2, R-AO27)
  # ===========================================================================

  describe "Pdf.Reader.read_annotations/1" do
    @tag :integration
    test "6.3a: returns {:ok, list, doc} when annotations present" do
      doc = open_doc(craft_annotation_pdf())
      assert {:ok, annotations, updated_doc} = Pdf.Reader.read_annotations(doc)
      assert is_list(annotations)
      assert length(annotations) == 1
      assert %Pdf.Reader.Document{} = updated_doc
    end

    @tag :integration
    test "6.3b: each annotation is a %Pdf.Reader.Annotation{} struct" do
      doc = open_doc(craft_annotation_pdf())
      assert {:ok, annotations, _doc} = Pdf.Reader.read_annotations(doc)
      Enum.each(annotations, fn a -> assert %Annotation{} = a end)
    end

    @tag :integration
    test "6.3c: returns {:ok, [], doc} when no /Annots on any page" do
      doc = open_doc(craft_no_annotation_pdf())
      assert {:ok, [], _doc} = Pdf.Reader.read_annotations(doc)
    end

    @tag :integration
    test "6.3d: delegates to Pdf.Reader.Annotations.read/1 (same result)" do
      doc = open_doc(craft_annotation_pdf())
      assert {:ok, anns_via_reader, _} = Pdf.Reader.read_annotations(doc)
      assert {:ok, anns_direct, _} = Pdf.Reader.Annotations.read(doc)
      assert anns_via_reader == anns_direct
    end
  end

  # ===========================================================================
  # Task 6.4 — Pdf.Reader.read_annotations!/1 bang variant (R-AO3)
  # ===========================================================================

  describe "Pdf.Reader.read_annotations!/1" do
    @tag :integration
    test "6.4a: returns list of annotations on success" do
      doc = open_doc(craft_annotation_pdf())
      annotations = Pdf.Reader.read_annotations!(doc)
      assert is_list(annotations)
      assert length(annotations) == 1
    end

    @tag :integration
    test "6.4b: returns empty list when no annotations" do
      doc = open_doc(craft_no_annotation_pdf())
      annotations = Pdf.Reader.read_annotations!(doc)
      assert annotations == []
    end

    @tag :integration
    test "6.4c: raises Pdf.Reader.Error when underlying call returns {:error, _}" do
      invalid_doc = %Pdf.Reader.Document{
        binary: <<0>>,
        version: "1.7",
        xref: %{},
        trailer: %{"Root" => {:ref, 999, 0}},
        cache: %{},
        page_refs: nil,
        encryption: nil
      }

      assert_raise Pdf.Reader.Error, fn ->
        Pdf.Reader.read_annotations!(invalid_doc)
      end
    end
  end
end
