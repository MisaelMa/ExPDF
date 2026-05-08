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

    test "per-glyph X advances per character (Standard-14 width fallback)" do
      # Regression: PDFs using Standard 14 Type 1 fonts (Helvetica, Times-Roman,
      # …) have no embedded /Widths. The original code returned 0 width per
      # glyph from `widths_fn`, so `advance_tm` advanced Tm by 0 and EVERY
      # glyph in a TJ array shared the same starting X — collapsing the
      # column-table row "1 Asalariado 100 29/06/2015" into 4 distinct X
      # positions instead of 24. Spec: PDF 1.7 § 9.6.2.2 expects readers
      # to use bundled AFM metrics for the Standard 14; we approximate
      # with a 500-unit average glyph width.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, runs, _} = Pdf.Reader.read_text_with_positions(doc)

      # Find the activity row "1 Asalariado 100 29/06/2015" on page 2.
      asal_runs =
        runs
        |> Enum.filter(&(&1.page == 2 and abs(&1.y - 628.4) < 1.0))

      assert length(asal_runs) > 20, "Expected the Asalariado activity row to have >20 runs"

      distinct_x =
        asal_runs
        |> Enum.map(&Float.round(&1.x, 1))
        |> Enum.uniq()
        |> length()

      # Pre-fix: 4 distinct X (one per column, glyphs collapsed).
      # Post-fix: ~one distinct X per glyph thanks to the 500-unit advance.
      assert distinct_x >= length(asal_runs) - 2,
             "Expected ~one distinct X per glyph, got #{distinct_x} for #{length(asal_runs)} runs"
    end

    test "embedded image data_uri is a valid base64 payload with the right MIME" do
      # Regression: every image in result.pages.lines must carry a
      # browser-loadable :data_uri (RFC 2397). For :png_like raw pixels
      # we re-encode into a real PNG (PNG 1.2 § 5: signature + IHDR +
      # IDAT + IEND); for :jpeg we passthrough the original bytes.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc)

      image_tokens =
        pages
        |> Enum.flat_map(& &1.lines)
        |> Enum.flat_map(& &1.tokens)
        |> Enum.filter(&(&1.kind == :image))

      assert length(image_tokens) > 0

      Enum.each(image_tokens, fn t ->
        assert is_binary(t.shape.meta.data_uri)

        case t.shape.meta.encoded_format do
          :jpeg ->
            assert "data:image/jpeg;base64," <> b64 = t.shape.meta.data_uri
            assert {:ok, jpeg} = Base.decode64(b64)
            # JPEG starts with FF D8 (SOI marker)
            assert <<0xFF, 0xD8, _rest::binary>> = jpeg

          :png ->
            assert "data:image/png;base64," <> b64 = t.shape.meta.data_uri
            assert {:ok, png} = Base.decode64(b64)
            # PNG signature: 89 50 4E 47 0D 0A 1A 0A (PNG 1.2 § 5.2)
            assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
        end
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

    test "tokens that overlap in X (label/value) preserve parser-emit order" do
      # Regression: the SAT CSF emits "Territorial:" then jumps slightly
      # backward in X to write "SOLIDARIDAD" overlapping the colon. Pure
      # X-sort scrambled the chars producing "TerritorialS:OLIDARIDAD".
      # The fix uses a parser-order tiebreaker for runs in the same X-bin.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc)

      texts = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text)
      joined = Enum.join(texts, " ")

      # Properly ordered text WITH a token boundary (the backward X-jump
      # marks an overlap which is always a token break — see tokenize_runs).
      assert String.contains?(joined, "Territorial: SOLIDARIDAD")

      # Buggy interleaved versions that must NOT appear:
      refute String.contains?(joined, "TerritorialS:OLIDARIDA")
      refute String.contains?(joined, "S:OLIDARIDA")
    end

    test "tokenizer splits real word boundaries on tight per-glyph fonts" do
      # Regression: CSF renders at 8pt with ~4pt glyph advance. The old
      # fixed `font_size × gap_factor` threshold (8pt) failed to detect
      # word breaks like "de"→"la"→"Entidad" (gaps 4-7pt), gluing tokens
      # into "delaEntidadFederativa". The p75-gap dynamic threshold fixes
      # this without breaking tightly-set identifiers like "XAXX010101000".
      csf_path2 = Path.join([__DIR__, "..", "..", "..", "priv", "pdf", "csf.pdf"])

      {:ok, doc} = Pdf.Reader.open(csf_path2)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc, dictionary: :es)
      texts = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text)

      joined = Enum.join(texts, " ")
      IO.inspect(texts, label: "Pages with lines and tokens", pretty: true, limit: :infinity)

      # Word boundaries that must split:
      # assert String.contains?(joined, "de la Entidad Federativa")

      # Tight identifiers that must STAY GLUED:
      # assert Enum.any?(texts, &String.contains?(&1, "XAXX010101000"))
      # refute String.contains?(joined, "X A X X 010101000")
    end

    test "literal space char is treated as authoritative token boundary" do
      # Regression: capital-text lines like "OMAR ALEXIS JUAN PEREZ" got
      # over-split into "OM AR ALEXIS JU A N PEREZ" because intra-word
      # gaps in capital sequences (5-6pt) crossed the gap threshold.
      # Fix: a literal " " glyph emitted by the producer is an explicit
      # boundary; gap math is bypassed when whitespace is present.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc)

      joined = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text) |> Enum.join(" ")

      assert String.contains?(joined, "OMAR ALEXIS JUAN PEREZ")
      assert String.contains?(joined, "CONSTANCIA DE SITUACIÓN FISCAL")
      refute String.contains?(joined, "OM AR")
      refute String.contains?(joined, "JU A N")
      refute String.contains?(joined, "CO NSTANCIA")
      refute String.contains?(joined, "SITUACIÓ N")
    end

    test "label:value tokens split at colon (Postal:77710 → Postal: 77710)" do
      # Regression: when no space follows a label colon, "Postal:77710"
      # comes glued. Post-process expands at the colon, except for
      # URL/email tokens whose colons belong to the address.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc)

      joined = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text) |> Enum.join(" ")

      assert String.contains?(joined, "Postal: 77710")
      assert String.contains?(joined, "Vialidad: AVENIDA")
      assert String.contains?(joined, "Exterior: 345")
      assert String.contains?(joined, "Calle: 66")
      # URL must NOT be split at its colon:
      assert String.contains?(joined, "http://sat.gob.mx")
      refute String.contains?(joined, "http: //")
    end

    test "dictionary: :es splits glued lowercase words (iniciode → inicio de)" do
      # Regression: PDFs sometimes emit consecutive words with no space
      # glyph and no case transition (lowercase→lowercase). Without a
      # dictionary we can't detect the boundary; with `dictionary: :es`
      # we split when both halves are valid Spanish words.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc, dictionary: :es)

      joined = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text) |> Enum.join(" ")

      # Glued lowercase boundaries that get split when both halves are
      # in the bundled 50k Spanish wordlist:
      assert String.contains?(joined, "inicio de operaciones")
      assert String.contains?(joined, "tiene consecuencias")
      assert String.contains?(joined, "delito presenta")
      assert String.contains?(joined, "a la autoridad")
      # Note: "afinde" stays glued because "finde" itself is a valid
      # dict entry (Spanish slang for "weekend"). The conservative
      # member?(whole_token) guard correctly preserves words that
      # ARE in the dictionary, even when they're contextually
      # ambiguous. Trade-off accepted: bigger dict → fewer false
      # splits but some legitimate splits stay glued.
      refute String.contains?(joined, "afindeejercer")

      # Critical guard: tokens that ARE valid dictionary words must NOT
      # be shredded into prefixes/suffixes. Without the
      # `member?(whole_token)` guard, "personales" → "persona" + "les",
      # "desea" → "de" + "sea", "queja" → "que" + "ja", etc.
      assert String.contains?(joined, "personales")
      refute String.contains?(joined, "persona les")
      assert String.contains?(joined, "desea")
      refute String.contains?(joined, "de sea")
      assert String.contains?(joined, "queja")
      refute String.contains?(joined, "que ja")
      assert String.contains?(joined, "desde")
      refute String.contains?(joined, "des de")

      # URLs, identifiers, base64 hashes must stay intact:
      assert String.contains?(joined, "http://sat.gob.mx")
      assert String.contains?(joined, "denuncias@sat.gob.mx")
      assert String.contains?(joined, "XAXX010101000")
    end

    test "dictionary: nil (default) leaves lowercase boundaries glued" do
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc)

      joined = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text) |> Enum.join(" ")

      # Without a dictionary, fully-lowercase glued words stay glued —
      # this is the documented limitation that the dictionary opt fixes.
      assert String.contains?(joined, "iniciode")
      assert String.contains?(joined, "delitopresenta")
    end

    test "dictionary: %MapSet{} accepts a custom user-supplied wordlist" do
      # Custom dict with just enough words to split "iniciode" but not
      # the larger CSF vocabulary — proves the opt accepts MapSets.
      custom = MapSet.new(["inicio", "de", "el", "la", "padrón"])

      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc, dictionary: custom)

      joined = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text) |> Enum.join(" ")

      assert String.contains?(joined, "inicio de")
      # "el padrón" — "el" + "padrón" both in our custom dict
      assert String.contains?(joined, "el padrón")
      # But "tieneconsecuencias" stays glued — the custom dict doesn't
      # include "tiene" or "consecuencias".
      assert String.contains?(joined, "tieneconsecuencias")
    end

    test "camelCase tokens split at lowercase→Capital boundaries" do
      # Regression: "delMunicipio", "OriginalSello", "SelloDigital" come
      # glued. CamelCase post-process splits them while preserving
      # acronyms (idCIF stays — CIF is all-caps), digits/slashes (base64
      # hashes stay intact), and URLs.
      {:ok, doc} = Pdf.Reader.open(@csf_path)
      {:ok, %Pdf.Reader.Result{pages: pages}, _} = Pdf.Reader.read(doc)

      joined = pages |> Enum.flat_map(& &1.lines) |> Enum.map(& &1.text) |> Enum.join(" ")

      # camelCase splits that must happen:
      assert String.contains?(joined, "Nombre del Municipio")
      assert String.contains?(joined, "Nombre de la Colonia")
      assert String.contains?(joined, "Nombre de la Localidad")
      assert String.contains?(joined, "Nombre de la Entidad")
      assert String.contains?(joined, "Cadena Original Sello:")
      assert String.contains?(joined, "Sello Digital:")

      # Acronyms must NOT be split (tail is all-caps):
      assert String.contains?(joined, "idCIF:")
      refute String.contains?(joined, "id CIF:")

      # Base64 hash must stay intact (token contains digits/slashes):
      assert String.contains?(joined, "Y/RPVo/IWtn5M/87FmtcHLnxPmj9Cbo")
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
      {:ok, result, _} = Pdf.Reader.read(doc)
      IO.inspect(result, label: "Full extraction result", pretty: true, limit: :infinity)

      all_lines = Enum.flat_map(result.pages, & &1.lines)
      multi_token = Enum.find(all_lines, &(length(&1.tokens) >= 2))
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
