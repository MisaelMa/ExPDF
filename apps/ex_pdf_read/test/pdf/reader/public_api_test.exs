defmodule Pdf.Reader.PublicApiTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # 9.3.x — page_count/1
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.page_count/1" do
    # 9.3.1 — correct page count from a single-page writer-generated PDF
    test "returns {:ok, 1} for a single-page PDF" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, 1} = Pdf.Reader.page_count(doc)
    end

    # 9.3.2 — page_count!/1 bang raises on error, returns value on success
    test "page_count!/1 returns integer directly" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert 1 = Pdf.Reader.page_count!(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # 9.4.x — read_text_with_positions/1
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_text_with_positions/1" do
    # 9.4.1 — returns TextRun structs from a writer-generated PDF
    test "returns text runs with positions" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)
      assert is_list(runs)
      # writer-generated PDF should have at least one text run
      assert runs != []
    end

    # 9.4.2 — each run is a TextRun struct with required fields
    test "each run has text, x, y, font, size, page fields" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, [run | _], _doc} = Pdf.Reader.read_text_with_positions(doc)
      assert is_binary(run.text)
      assert is_float(run.x) or is_integer(run.x)
      assert is_float(run.y) or is_integer(run.y)
      assert is_integer(run.page)
      assert run.page == 1
    end

    # 9.4.3 — empty PDF (no text operators) returns {:ok, []}
    test "returns {:ok, []} when no text in PDF" do
      bin = build_empty_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)
      assert runs == []
    end

    # 9.4.4 — Form XObject Do does NOT recurse, no error
    # (Writer doesn't emit Form XObjects, so we test that Do with a form ref
    # produces no text runs and no error — covered by the content stream test,
    # but we verify the public API doesn't error on a real PDF with no forms)
    test "does not error on a PDF that has no form xobjects" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, _runs, _doc} = Pdf.Reader.read_text_with_positions(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # 9.5.x — read_text/2
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_text/2" do
    # 9.5.1 — returns list of page strings
    test "returns {:ok, [page_string]} for a single-page PDF" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts, _doc} = Pdf.Reader.read_text(doc)
      assert is_list(texts)
    end

    # 9.5.2 — text contains the written string
    test "page text contains 'Hello, world!'" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, texts, _doc} = Pdf.Reader.read_text(doc)
      full_text = Enum.join(texts, " ")
      assert String.contains?(full_text, "Hello, world!")
    end

    # 9.5.3 — empty PDF returns {:ok, []}
    test "returns {:ok, []} when no text" do
      bin = build_empty_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, [], _doc} = Pdf.Reader.read_text(doc)
    end

    # 9.5.4 — pages: option filters to specific page numbers
    test "pages: [1] returns only page 1 text" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts_all, _doc} = Pdf.Reader.read_text(doc)
      assert {:ok, texts_p1, _doc} = Pdf.Reader.read_text(doc, pages: [1])
      # For a 1-page PDF both should return the same content
      assert texts_p1 == texts_all
    end
  end

  # ---------------------------------------------------------------------------
  # 9.6.x — close/1 + bang wrappers
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.close/1" do
    # 9.6.1 — close always returns :ok
    test "returns :ok and never raises" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert :ok = Pdf.Reader.close(doc)
    end
  end

  describe "bang wrappers" do
    # 9.6.2 — open! raises on error
    test "open!/1 raises Pdf.Reader.Error on invalid input" do
      assert_raise Pdf.Reader.Error, fn ->
        Pdf.Reader.open!("not a pdf binary")
      end
    end

    # 9.6.3 — read_text!/2 and read_text_with_positions!/1 return values on success
    test "read_text!/2 returns list of strings on success" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_text!(doc)
      assert is_list(result)
    end

    test "read_text_with_positions!/1 returns list on success" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_text_with_positions!(doc)
      assert is_list(result)
    end

    test "read_images!/1 returns list on success" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_images!(doc)
      assert is_list(result)
    end

    test "read_metadata!/1 returns map on success" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_metadata!(doc)
      assert is_map(result)
    end

    test "page_count!/1 returns integer on success" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.page_count!(doc)
      assert is_integer(result)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 5: read_acroform/1 and read_acroform!/1 delegation (S-AF18, R-AF19)
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_acroform/1 and read_acroform!/1" do
    test "5.1a: read_acroform/1 on a PDF with no AcroForm returns {:ok, [], doc}" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, [], _doc} = Pdf.Reader.read_acroform(doc)
    end

    test "5.1b: read_acroform!/1 returns list on success (no AcroForm → [])" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      result = Pdf.Reader.read_acroform!(doc)
      assert result == []
    end

    test "5.1c: read_acroform!/1 raises Pdf.Reader.Error on error" do
      # We inject a broken document to force an error — corrupted trailer Root ref
      bin = build_broken_root_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)

      assert_raise Pdf.Reader.Error, fn ->
        Pdf.Reader.read_acroform!(doc)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7.3 — CID regression guard (S-CID14, R-CID13b)
  # ---------------------------------------------------------------------------

  describe "CID regression guard — simple fonts unaffected (S-CID14, R-CID13b)" do
    test "existing simple-font (Helvetica/WinAnsi) PDF still decodes correctly after CID path added" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, texts, _doc} = Pdf.Reader.read_text(doc)
      full_text = Enum.join(texts, " ")
      # The writer-generated PDF uses Helvetica with WinAnsiEncoding.
      # The simple 1-byte path must remain intact.
      assert String.contains?(full_text, "Hello, world!")
    end

    test "simple-font PDF returns valid UTF-8 runs with no crashes after CID code added" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, runs, _doc} = Pdf.Reader.read_text_with_positions(doc)

      for run <- runs do
        assert String.valid?(run.text)
        assert is_list(run.unresolved)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_simple_pdf do
    Pdf.build([size: :a4, compress: false], fn pdf ->
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({72, 720}, "Hello, world!")
    end)
    |> Pdf.export()
  end

  defp build_empty_pdf do
    Pdf.build([size: :a4, compress: false], fn pdf ->
      # No text operations — just a blank page
      pdf
    end)
    |> Pdf.export()
  end

  # Build a PDF with a broken /Root reference (points to non-existent obj)
  # to force {:error, _} on read_acroform
  defp build_broken_root_pdf do
    header = "%PDF-1.4\n"
    # No real objects — just a trailer pointing to Root 99 0 R which doesn't exist
    obj1 = "1 0 obj\n42\nendobj\n"

    obj1_offset = byte_size(header)
    xref_offset = obj1_offset + byte_size(obj1)

    xref =
      "xref\n0 2\n" <>
        "0000000000 65535 f\r\n" <>
        pad_offset(obj1_offset) <> " 00000 n\r\n"

    # Root points to obj 99 which does not exist → resolve_catalog will fail
    trailer =
      "trailer\n<</Size 2 /Root 99 0 R>>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header <> obj1 <> xref <> trailer
  end

  defp pad_offset(n) do
    n |> Integer.to_string() |> String.pad_leading(10, "0")
  end
end
