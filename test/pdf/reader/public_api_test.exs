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
      assert {:ok, runs} = Pdf.Reader.read_text_with_positions(doc)
      assert is_list(runs)
      # writer-generated PDF should have at least one text run
      assert length(runs) >= 1
    end

    # 9.4.2 — each run is a TextRun struct with required fields
    test "each run has text, x, y, font, size, page fields" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, [run | _]} = Pdf.Reader.read_text_with_positions(doc)
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
      assert {:ok, runs} = Pdf.Reader.read_text_with_positions(doc)
      assert runs == []
    end

    # 9.4.4 — Form XObject Do does NOT recurse, no error
    # (Writer doesn't emit Form XObjects, so we test that Do with a form ref
    # produces no text runs and no error — covered by the content stream test,
    # but we verify the public API doesn't error on a real PDF with no forms)
    test "does not error on a PDF that has no form xobjects" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, _runs} = Pdf.Reader.read_text_with_positions(doc)
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
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert is_list(texts)
    end

    # 9.5.2 — text contains the written string
    test "page text contains 'Hello, world!'" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      {:ok, texts} = Pdf.Reader.read_text(doc)
      full_text = Enum.join(texts, " ")
      assert String.contains?(full_text, "Hello, world!")
    end

    # 9.5.3 — empty PDF returns {:ok, []}
    test "returns {:ok, []} when no text" do
      bin = build_empty_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, []} = Pdf.Reader.read_text(doc)
    end

    # 9.5.4 — pages: option filters to specific page numbers
    test "pages: [1] returns only page 1 text" do
      bin = build_simple_pdf()
      {:ok, doc} = Pdf.Reader.open(bin)
      assert {:ok, texts_all} = Pdf.Reader.read_text(doc)
      assert {:ok, texts_p1} = Pdf.Reader.read_text(doc, pages: [1])
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
end
