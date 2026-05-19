defmodule Pdf.Reader.ReaderOutlinesTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Outline

  # ---------------------------------------------------------------------------
  # PDF fixture builders — minimal hand-crafted PDFs for delegation tests.
  # Same build_pdf/4 + pad_offset/1 pattern as outlines_test.exs.
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

  # Minimal PDF with a flat outline tree (1 entry)
  defp craft_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R /Outlines 4 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"
    obj4 = "4 0 obj\n<</Type /Outlines /First 5 0 R /Count 1>>\nendobj\n"
    obj5 = "5 0 obj\n<</Title (Section 1) /Parent 4 0 R>>\nendobj\n"

    build_pdf([obj1, obj2, obj3, obj4, obj5], header, 6, "1 0 R")
  end

  # Minimal PDF with no outlines
  defp craft_no_outline_pdf do
    header = "%PDF-1.4\n"

    obj1 = "1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n"
    obj2 = "2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n"
    obj3 = "3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]>>\nendobj\n"

    build_pdf([obj1, obj2, obj3], header, 4, "1 0 R")
  end

  # ===========================================================================
  # Task 6.1 — Pdf.Reader.read_outlines/1 happy-path delegation (R-AO1, R-AO27)
  # ===========================================================================

  describe "Pdf.Reader.read_outlines/1" do
    @tag :integration
    test "6.1a: returns {:ok, list, doc} when outlines present" do
      doc = open_doc(craft_outline_pdf())
      assert {:ok, outlines, updated_doc} = Pdf.Reader.read_outlines(doc)
      assert is_list(outlines)
      assert length(outlines) == 1
      assert %Pdf.Reader.Document{} = updated_doc
    end

    @tag :integration
    test "6.1b: each outline is a %Pdf.Reader.Outline{} struct" do
      doc = open_doc(craft_outline_pdf())
      assert {:ok, outlines, _doc} = Pdf.Reader.read_outlines(doc)
      Enum.each(outlines, fn o -> assert %Outline{} = o end)
    end

    @tag :integration
    test "6.1c: returns {:ok, [], doc} when no /Outlines in catalog" do
      doc = open_doc(craft_no_outline_pdf())
      assert {:ok, [], _doc} = Pdf.Reader.read_outlines(doc)
    end

    @tag :integration
    test "6.1d: delegates to Pdf.Reader.Outlines.read/1 (same result)" do
      doc = open_doc(craft_outline_pdf())
      assert {:ok, outlines_via_reader, _} = Pdf.Reader.read_outlines(doc)
      assert {:ok, outlines_direct, _} = Pdf.Reader.Outlines.read(doc)
      assert outlines_via_reader == outlines_direct
    end
  end

  # ===========================================================================
  # Task 6.2 — Pdf.Reader.read_outlines!/1 bang variant (R-AO3)
  # ===========================================================================

  describe "Pdf.Reader.read_outlines!/1" do
    @tag :integration
    test "6.2a: returns list of outlines on success" do
      doc = open_doc(craft_outline_pdf())
      outlines = Pdf.Reader.read_outlines!(doc)
      assert is_list(outlines)
      assert length(outlines) == 1
    end

    @tag :integration
    test "6.2b: returns empty list when no outlines" do
      doc = open_doc(craft_no_outline_pdf())
      outlines = Pdf.Reader.read_outlines!(doc)
      assert outlines == []
    end

    @tag :integration
    test "6.2c: raises Pdf.Reader.Error when underlying call returns {:error, _}" do
      # Inject an error by calling read_outlines! on a fake doc that would fail.
      # We simulate by mocking through a direct call: craft a document where
      # Outlines.read would fail — we do this by building a malformed outlines ref.
      # Actually the simplest approach: pass a doc with a root that resolves to
      # an object without "Outlines" key via normal path. For the RAISE path we
      # force an error using an invalid document struct.
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
        Pdf.Reader.read_outlines!(invalid_doc)
      end
    end
  end
end
