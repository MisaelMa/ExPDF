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

  describe "real-world CSF — line reconstruction" do
    test "read_lines/1 produces logical lines with tokens" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, lines, _doc} = Pdf.Reader.read_lines(doc)

      # Sanity: the CSF has many lines across 2 pages.
      assert length(lines) > 30
      assert Enum.all?(lines, &(&1.page in 1..2))

      # Every line carries its position and at least one token.
      Enum.each(lines, fn line ->
        assert is_number(line.y)
        assert is_number(line.x)
        assert line.tokens != []
        assert is_binary(line.text)
      end)
    end

    test "RFC, idCIF and CURP appear as detectable line content" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, lines, _} = Pdf.Reader.read_lines(doc)

      texts = Enum.map(lines, & &1.text)

      assert Enum.any?(texts, &String.contains?(&1, "XAXX010101000"))
      assert Enum.any?(texts, &String.contains?(&1, "17030554538"))
      assert Enum.any?(texts, &String.contains?(&1, "XEXX010101HNEXXXA4"))
    end

    test "the Asalariado activity row is detected as a multi-token line" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, lines, _} = Pdf.Reader.read_lines(doc)

      activity_line =
        Enum.find(lines, fn line ->
          String.contains?(line.text, "Asalariado") and
            String.contains?(line.text, "29/06/2015")
        end)

      assert activity_line != nil, "Could not find the Asalariado activity row"
      assert activity_line.page == 2
      # Order column + activity name + percentage + start date = 3+ tokens
      assert length(activity_line.tokens) >= 3

      xs = Enum.map(activity_line.tokens, & &1.x)
      assert xs == Enum.sort(xs), "Tokens must be ordered left-to-right"
    end

    test "tokens within a line have distinct X positions" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, lines, _} = Pdf.Reader.read_lines(doc)

      IO.inspect(lines, label: "Multi-token line for distinct X positions test")

      multi_token = Enum.find(lines, &(length(&1.tokens) >= 2))

      assert multi_token != nil

      xs = Enum.map(multi_token.tokens, & &1.x)
      assert xs == Enum.uniq(xs)
    end
  end

  describe "real-world CSF — shape extraction (URLs and emails)" do
    test "read_shapes/1 returns inferred URL and email shapes from page 2" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, shapes, _doc} = Pdf.Reader.read_shapes(doc)

      # The CSF prints these as plain text (no link annotations) — they should
      # appear as inferred shapes.
      targets = Enum.map(shapes, & &1.target)

      assert "http://sat.gob.mx" in targets
      assert "denuncias@sat.gob.mx" in targets

      # Every shape from this CSF is inferred (no annotations in this PDF).
      assert Enum.all?(shapes, &(&1.source == :inferred))
    end

    test "shape types are correctly classified (uri vs email)" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, shapes, _} = Pdf.Reader.read_shapes(doc)

      uri_shape = Enum.find(shapes, &(&1.target == "http://sat.gob.mx"))
      assert uri_shape.type == :uri

      email_shape = Enum.find(shapes, &(&1.target == "denuncias@sat.gob.mx"))
      assert email_shape.type == :email
    end

    test "every inferred shape carries a positional rect on the right page" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, shapes, _} = Pdf.Reader.read_shapes(doc)

      Enum.each(shapes, fn shape ->
        assert shape.page in 1..2
        assert {x1, y1, x2, y2} = shape.rect
        assert is_number(x1) and is_number(y1)
        assert is_number(x2) and is_number(y2)
        assert x2 >= x1
      end)
    end
  end
end
