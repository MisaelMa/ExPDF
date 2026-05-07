defmodule Pdf.Reader.FixturesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Real-world fixture tests for `Pdf.Reader`.

  All tests in this module are tagged `@tag :fixtures` and are **excluded from
  the default `mix test` run**. Run them explicitly with:

      mix test --only fixtures

  or together with the regular suite via:

      mix test --include fixtures

  ## Fixtures

  | File | Source | Pages | License |
  |------|--------|-------|---------|
  | `rfc.pdf` | RFC 8259 (JSON spec), rfc-editor.org | 16 | IETF Trust (redistributable) |
  | `gov.pdf` | IRS Form W-9, irs.gov | 6 | US gov work, public domain 17 USC § 105 |
  | `sample.pdf` | RFC 793 (TCP spec), rfc-editor.org | 91 | IETF Trust (redistributable) |

  ## Phase 1.1 text cascade notes

  After cascade wiring (Phase 1.1) ASCII-dominant PDFs decode correctly.
  `sample.pdf` (RFC 793) uses Type1 fonts without ToUnicode CMaps — the cascade
  falls back to U+FFFD for those glyphs. Tests verify UTF-8 validity and
  non-empty output, not specific substrings, for that fixture.

  ## Page count stability note

  The page counts in test 11.6 are "discovered" values — they were obtained by running
  `page_count/1` on the actual committed fixtures and hardcoding the result. The tests verify
  **stability** (same fixture always reports the same count), not external truth.
  """

  @fixtures_dir Path.expand("../../fixtures/pdfs", __DIR__)
  @rfc_pdf Path.join(@fixtures_dir, "rfc.pdf")
  @gov_pdf Path.join(@fixtures_dir, "gov.pdf")
  @sample_pdf Path.join(@fixtures_dir, "sample.pdf")

  # ---------------------------------------------------------------------------
  # 11.4 — open/1 returns {:ok, doc} for all three fixtures
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.open/1 — real-world fixtures (11.4)" do
    @tag :fixtures
    test "opens rfc.pdf (RFC 8259, 22 KB, PDF 1.4, classic xref)" do
      assert {:ok, doc} = Pdf.Reader.open(@rfc_pdf)
      assert is_binary(doc.version)
      assert doc.version =~ ~r/^\d+\.\d+$/
      assert map_size(doc.xref) > 0
    end

    @tag :fixtures
    test "opens gov.pdf (IRS W-9, 140 KB, PDF 1.7, xref stream)" do
      assert {:ok, doc} = Pdf.Reader.open(@gov_pdf)
      assert is_binary(doc.version)
      assert doc.version =~ ~r/^\d+\.\d+$/
      assert map_size(doc.xref) > 0
    end

    @tag :fixtures
    test "opens sample.pdf (RFC 793, 104 KB, PDF 1.2, classic xref)" do
      assert {:ok, doc} = Pdf.Reader.open(@sample_pdf)
      assert is_binary(doc.version)
      assert doc.version =~ ~r/^\d+\.\d+$/
      assert map_size(doc.xref) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # 11.5 — read_text/1 returns {:ok, list} with non-empty strings
  # Phase 9 strengthening: specific text fragment assertions and UTF-8 validity
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_text/1 — real-world fixtures (11.5)" do
    @tag :fixtures
    test "extracts non-empty text list from rfc.pdf" do
      {:ok, doc} = Pdf.Reader.open(@rfc_pdf)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      # Must be a non-empty list
      assert is_list(texts)
      assert length(texts) > 0
      # At least one entry must be a non-empty string
      assert Enum.any?(texts, fn t -> is_binary(t) and byte_size(t) > 0 end)
    end

    @tag :fixtures
    test "extracts non-empty text list from gov.pdf" do
      {:ok, doc} = Pdf.Reader.open(@gov_pdf)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert is_list(texts)
      assert length(texts) > 0
      assert Enum.any?(texts, fn t -> is_binary(t) and byte_size(t) > 0 end)
    end

    @tag :fixtures
    test "extracts non-empty text list from sample.pdf" do
      {:ok, doc} = Pdf.Reader.open(@sample_pdf)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert is_list(texts)
      assert length(texts) > 0
      assert Enum.any?(texts, fn t -> is_binary(t) and byte_size(t) > 0 end)
    end

    # Phase 9.1 — rfc.pdf (RFC 8259, JSON spec) must contain "JSON" or "8259" (S-CW15)
    @tag :fixtures
    test "9.1: rfc.pdf read_text — contains 'JSON' or '8259' (S-CW15)" do
      {:ok, doc} = Pdf.Reader.open(@rfc_pdf)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert length(texts) >= 1

      joined = Enum.join(texts, " ")

      # All page strings must be valid UTF-8 (cascade is working, not raw bytes)
      assert Enum.all?(texts, &String.valid?/1),
             "All page strings must be valid UTF-8; got raw bytes for some pages"

      # The cascade must decode enough text to find RFC 8259 keywords
      assert String.contains?(joined, "JSON") or String.contains?(joined, "8259") or
               String.contains?(joined, "JavaScript"),
             "Expected rfc.pdf to contain 'JSON' or '8259' — got: #{String.slice(joined, 0, 200)}"
    end

    # Phase 9.2 — gov.pdf (IRS W-9) must contain W-9 form keywords
    @tag :fixtures
    test "9.2a: gov.pdf read_text — contains 'W-9' or 'Taxpayer' or 'IRS'" do
      {:ok, doc} = Pdf.Reader.open(@gov_pdf)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert length(texts) > 0

      joined = Enum.join(texts, " ")
      assert Enum.all?(texts, &String.valid?/1)

      assert String.contains?(joined, "W-9") or String.contains?(joined, "Taxpayer") or
               String.contains?(joined, "IRS"),
             "Expected gov.pdf to contain W-9 form keywords — got: #{String.slice(joined, 0, 200)}"
    end

    # Phase 9.2 — sample.pdf (RFC 793 TCP) — encoding yields U+FFFD for CID fonts;
    # assert non-empty list with valid UTF-8 strings (best-effort for legacy encoding)
    @tag :fixtures
    test "9.2b: sample.pdf read_text — non-empty list with valid UTF-8 strings per page" do
      {:ok, doc} = Pdf.Reader.open(@sample_pdf)
      assert {:ok, texts} = Pdf.Reader.read_text(doc)
      assert length(texts) > 0

      # All page strings must be valid UTF-8 (U+FFFD is valid; raw Latin-1 is not)
      assert Enum.all?(texts, &String.valid?/1),
             "All page strings must be valid UTF-8"

      assert Enum.all?(texts, fn t -> is_binary(t) and byte_size(t) > 0 end),
             "Each page string must be non-empty"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 9.3 — read_metadata/1 on each fixture returns at least one known key
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_metadata/1 — real-world fixtures (9.3)" do
    @known_meta_keys ~w(Title Author Producer Creator)

    @tag :fixtures
    test "9.3a: rfc.pdf — read_metadata returns at least one of Title|Author|Producer|Creator" do
      {:ok, doc} = Pdf.Reader.open(@rfc_pdf)
      assert {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)
      assert is_map(meta)

      assert Enum.any?(@known_meta_keys, &Map.has_key?(meta, &1)),
             "Expected at least one of #{inspect(@known_meta_keys)} in #{inspect(meta)}"
    end

    @tag :fixtures
    test "9.3b: gov.pdf — read_metadata returns at least one of Title|Author|Producer|Creator" do
      {:ok, doc} = Pdf.Reader.open(@gov_pdf)
      assert {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)
      assert is_map(meta)

      assert Enum.any?(@known_meta_keys, &Map.has_key?(meta, &1)),
             "Expected at least one of #{inspect(@known_meta_keys)} in #{inspect(meta)}"
    end

    @tag :fixtures
    test "9.3c: sample.pdf — read_metadata returns at least one of Title|Author|Producer|Creator" do
      {:ok, doc} = Pdf.Reader.open(@sample_pdf)
      assert {:ok, meta, _doc2} = Pdf.Reader.read_metadata(doc)
      assert is_map(meta)

      assert Enum.any?(@known_meta_keys, &Map.has_key?(meta, &1)),
             "Expected at least one of #{inspect(@known_meta_keys)} in #{inspect(meta)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 9.4 — read_images/1 on each fixture
  # None of the three fixtures have extractable images (unsupported filters or
  # no images), so assert {:ok, []} for all.
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.read_images/1 — real-world fixtures (9.4)" do
    @tag :fixtures
    test "9.4a: rfc.pdf — read_images returns {:ok, list} (may be empty)" do
      {:ok, doc} = Pdf.Reader.open(@rfc_pdf)
      assert {:ok, images} = Pdf.Reader.read_images(doc)
      assert is_list(images)

      # If images present, each must have a 6-tuple ctm and positive render_width
      if length(images) > 0 do
        Enum.each(images, fn img ->
          assert is_tuple(img.ctm) and tuple_size(img.ctm) == 6
          assert img.render_width > 0.0
        end)
      end
    end

    @tag :fixtures
    test "9.4b: gov.pdf — read_images returns {:ok, list} (may be empty)" do
      {:ok, doc} = Pdf.Reader.open(@gov_pdf)
      assert {:ok, images} = Pdf.Reader.read_images(doc)
      assert is_list(images)

      if length(images) > 0 do
        Enum.each(images, fn img ->
          assert is_tuple(img.ctm) and tuple_size(img.ctm) == 6
          assert img.render_width > 0.0
        end)
      end
    end

    @tag :fixtures
    test "9.4c: sample.pdf — read_images returns {:ok, list} (may be empty)" do
      {:ok, doc} = Pdf.Reader.open(@sample_pdf)
      assert {:ok, images} = Pdf.Reader.read_images(doc)
      assert is_list(images)

      if length(images) > 0 do
        Enum.each(images, fn img ->
          assert is_tuple(img.ctm) and tuple_size(img.ctm) == 6
          assert img.render_width > 0.0
        end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 11.6 — page_count/1 matches discovered page count for each fixture
  #
  # NOTE: These counts were discovered by running page_count/1 on the actual
  # committed fixture files, not by consulting external metadata. The tests
  # verify that the reader reports a stable, consistent count for the same file.
  # ---------------------------------------------------------------------------

  describe "Pdf.Reader.page_count/1 — real-world fixtures (11.6)" do
    # Discovered page count: 16 (PDF 1.4 /Count entry = 16)
    @tag :fixtures
    test "rfc.pdf has 16 pages" do
      {:ok, doc} = Pdf.Reader.open(@rfc_pdf)
      assert {:ok, 16} = Pdf.Reader.page_count(doc)
    end

    # Discovered page count: 6 (PDF 1.7 /Count entry = 6)
    @tag :fixtures
    test "gov.pdf has 6 pages" do
      {:ok, doc} = Pdf.Reader.open(@gov_pdf)
      assert {:ok, 6} = Pdf.Reader.page_count(doc)
    end

    # Discovered page count: 91 (PDF 1.2 /Count entry = 91)
    @tag :fixtures
    test "sample.pdf has 91 pages" do
      {:ok, doc} = Pdf.Reader.open(@sample_pdf)
      assert {:ok, 91} = Pdf.Reader.page_count(doc)
    end
  end
end
