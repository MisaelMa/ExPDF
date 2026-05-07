defmodule Pdf.Reader.CsfTest do
  @moduledoc """
  End-to-end text extraction smoke test against a real-world CSF
  (Cédula de Identificación Fiscal — Mexican tax ID document) PDF.

  Exercises the full reader pipeline: open → page tree walk → font
  decoder cascade → content-stream interpretation → per-glyph advance.
  """
  use ExUnit.Case, async: true

  @csf_path Path.join([__DIR__, "..", "..", "..", "priv", "pdf", "csf.pdf"])

  # The CSF places glyphs individually (TJ with kerning between every
  # character), which our reader joins with spaces. Normalize before
  # asserting so the test is robust to that layout choice.
  defp normalize(text) do
    text
    |> String.replace(~r/\s+/u, "")
    |> String.upcase()
  end

  describe "real-world CSF (Cédula de Identificación Fiscal)" do
    test "opens, reports 2 pages, and exposes empty recovery_log" do
      assert {:ok, doc} = Pdf.Reader.open(@csf_path)
      assert {:ok, 2} = Pdf.Reader.page_count(doc)
      assert Pdf.Reader.recovery_log(doc) == []
    end

    test "extracts the document title from page 1" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, [page1, _page2], _doc} = Pdf.Reader.read_text(doc)

      page1_n = normalize(page1)

      assert page1_n =~ "CÉDULADEIDENTIFICACIÓNFISCAL"
      assert page1_n =~ "REGISTROFEDERALDECONTRIBUYENTES"
    end

    test "extracts the RFC, idCIF, and taxpayer name from page 1" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, [page1, _], _} = Pdf.Reader.read_text(doc)
      page1_n = normalize(page1)

      # RFC (Registro Federal de Contribuyentes — Mexican tax ID format)
      assert page1_n =~ "XAXX010101000"
      # idCIF — internal tax-document identifier
      assert page1_n =~ "IDCIF:17030554538"
      # Taxpayer name
      assert page1_n =~ "OMARALEXISJUANPEREZ"
    end

    test "extracts the economic activity and tax regime from page 2" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, [_, page2], _} = Pdf.Reader.read_text(doc)
      page2_n = normalize(page2)

      assert page2_n =~ "ACTIVIDADESECONÓMICAS"
      assert page2_n =~ "ASALARIADO"
      # Régimen — collapse "Régimen de Sueldos y Salarios"
      assert page2_n =~ "RÉGIMENDESUELDOSYSALARIOS"
      # Start date for the Asalariado activity
      assert page2_n =~ "29/06/2015"
    end

    test "every page produces non-empty UTF-8 valid text" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, pages, _} = Pdf.Reader.read_text(doc)

      assert length(pages) == 2

      Enum.each(pages, fn page ->
        assert byte_size(page) > 0
        assert String.valid?(page)
      end)
    end

    test "read_text_with_positions returns runs with absolute coordinates" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, runs, _} = Pdf.Reader.read_text_with_positions(doc)

      # The CSF should produce many runs across both pages.
      assert length(runs) > 50

      # Each run carries page, x, y, font, and text.
      Enum.each(runs, fn run ->
        assert is_integer(run.page) and run.page in 1..2
        assert is_number(run.x)
        assert is_number(run.y)
        assert is_binary(run.text)
      end)
    end
  end
end
