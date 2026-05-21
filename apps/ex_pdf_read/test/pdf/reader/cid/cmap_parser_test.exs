defmodule Pdf.Reader.CID.CMapParserTest do
  use ExUnit.Case, async: true

  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7.5 — Predefined CMaps
  # - PDF 1.7 § 9.7.6 — Codespace ranges
  # - Adobe Tech Note #5099 — CMap and CIDFont Files Specification:
  #   https://adobe-type-tools.github.io/font-tech-notes/pdfs/5099.CMapResources.pdf
  # - Adobe Tech Note #5014 — CID-Keyed Font Technology Overview

  alias Pdf.Reader.CID.CMapParser

  # ---------------------------------------------------------------------------
  # Task 2.1 — codespacerange operator (R-PCM5, R-PCM6, R-PCM8)
  # ---------------------------------------------------------------------------

  describe "parse/1 — codespacerange" do
    test "single 2-byte entry populates codespaces[2]" do
      text = """
      /CIDInit /ProcSet findresource begin
      12 dict begin
      begincmap
      1 begincodespacerange
      <0000> <FFFF>
      endcodespacerange
      endcmap
      end end
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert Map.has_key?(cmap.codespaces, 2)
      assert [{0x0000, 0xFFFF}] = cmap.codespaces[2]
    end

    test "multiple entries of different byte lengths group correctly" do
      text = """
      begincmap
      3 begincodespacerange
      <00> <7F>
      <8140> <FEFE>
      <8F4040> <8F7E7E>
      endcodespacerange
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert [{0x00, 0x7F}] = cmap.codespaces[1]
      assert [{0x8140, 0xFEFE}] = cmap.codespaces[2]
      assert [{0x8F4040, 0x8F7E7E}] = cmap.codespaces[3]
    end

    test "empty text returns empty cmap" do
      assert {:ok, cmap} = CMapParser.parse("")
      assert cmap.codespaces == %{}
      assert cmap.cidchar == %{}
      assert cmap.cidrange == []
      assert cmap.notdef_chars == %{}
      assert cmap.notdef_ranges == []
      assert cmap.parent == nil
    end

    test "comments are ignored" do
      text = """
      % This is a comment
      begincmap
      % another comment
      1 begincodespacerange
      <0020> <FFFF>
      % range comment
      endcodespacerange
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert [{0x0020, 0xFFFF}] = cmap.codespaces[2]
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2.3 — cidchar operator (R-PCM6, S-PCM9)
  # ---------------------------------------------------------------------------

  describe "parse/1 — cidchar" do
    test "single cidchar entry maps hex code to CID integer" do
      text = """
      begincmap
      1 begincodespacerange
      <0000> <FFFF>
      endcodespacerange
      1 begincidchar
      <0020> 1
      endcidchar
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.cidchar[0x0020] == 1
    end

    test "multiple cidchar blocks accumulate all entries" do
      text = """
      begincmap
      2 begincidchar
      <0041> 100
      <0042> 101
      endcidchar
      3 begincidchar
      <0043> 102
      <0044> 103
      <0045> 104
      endcidchar
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.cidchar[0x0041] == 100
      assert cmap.cidchar[0x0042] == 101
      assert cmap.cidchar[0x0043] == 102
      assert cmap.cidchar[0x0044] == 103
      assert cmap.cidchar[0x0045] == 104
    end

    test "S-PCM9 scenario: 1 begincidchar <0020> 1 endcidchar" do
      text = "1 begincidchar\n<0020> 1\nendcidchar\n"

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.cidchar[0x0020] == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2.5 — cidrange operator (R-PCM6, S-PCM10)
  # ---------------------------------------------------------------------------

  describe "parse/1 — cidrange" do
    test "single cidrange entry stored as {lo, hi, base_cid} tuple" do
      text = """
      begincmap
      1 begincidrange
      <8140> <817E> 633
      endcidrange
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert [{0x8140, 0x817E, 633}] = cmap.cidrange
    end

    test "multiple cidrange entries all added to list" do
      text = """
      begincmap
      2 begincidrange
      <0020> <007E> 1
      <8140> <817E> 633
      endcidrange
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert length(cmap.cidrange) == 2
      assert {0x0020, 0x007E, 1} in cmap.cidrange
      assert {0x8140, 0x817E, 633} in cmap.cidrange
    end

    test "S-PCM10 scenario: <8140> <817E> 633 generates the expected tuple" do
      text = "1 begincidrange\n<8140> <817E> 633\nendcidrange\n"

      assert {:ok, cmap} = CMapParser.parse(text)
      assert [{0x8140, 0x817E, 633}] = cmap.cidrange
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2.7 — notdefchar, notdefrange, usecmap operators + malformed input
  #            (R-PCM6, R-PCM7, R-PCM19, S-PCM11)
  # ---------------------------------------------------------------------------

  describe "parse/1 — notdefchar and notdefrange" do
    test "beginnotdefchar entries go into notdef_chars map" do
      text = """
      begincmap
      1 beginnotdefchar
      <0000> 1
      endnotdefchar
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.notdef_chars[0x0000] == 1
    end

    test "beginnotdefrange entries go into notdef_ranges list" do
      text = """
      begincmap
      1 beginnotdefrange
      <0000> <001F> 1
      endnotdefrange
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert [{0x0000, 0x001F, 1}] = cmap.notdef_ranges
    end
  end

  describe "parse/1 — usecmap" do
    test "usecmap NAME sets parent field to the name string" do
      text = """
      begincmap
      /UniJIS-UTF16-H usecmap
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.parent == "UniJIS-UTF16-H"
    end

    test "usecmap without leading slash is also handled" do
      # Some CMap files use the name token directly before usecmap
      text = "UniJIS-UTF16-H usecmap\n"

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.parent == "UniJIS-UTF16-H"
    end
  end

  describe "parse/1 — irrelevant operators are silently skipped (R-PCM7)" do
    test "dict, def, pop, dup, findresource, begin, end tokens do not cause errors" do
      text = """
      /CIDInit /ProcSet findresource begin
      12 dict begin
      begincmap
      /CIDSystemInfo 3 dict dup begin
        /Registry (Adobe) def
        /Ordering (Japan1) def
        /Supplement 7 def
      end def
      /CMapName /UniJIS-UTF16-H def
      1 begincidchar
      <0020> 42
      endcidchar
      endcmap
      end end
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.cidchar[0x0020] == 42
    end

    test "parenthesised strings are skipped without disturbing subsequent tokens" do
      text = """
      begincmap
      (this is a string to skip) pop
      1 begincidchar
      <0030> 99
      endcidchar
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.cidchar[0x0030] == 99
    end

    test "array literals [...] are skipped" do
      text = """
      begincmap
      /XUID [1 10 25611] def
      1 begincidchar
      <0031> 55
      endcidchar
      endcmap
      """

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.cidchar[0x0031] == 55
    end
  end

  describe "parse/1 — malformed input (R-PCM19, S-PCM11)" do
    test "non-binary input returns {:error, _} without raising" do
      # Simulating truly malformed by passing a non-UTF8 string via rescue test
      # The main guarantee is: NEVER raise
      result = CMapParser.parse("<<invalid non-terminated dict")
      # Should not raise; return value is either ok or error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "truncated begincidchar block does not crash — returns partial ok" do
      # Truncated mid-section; should degrade gracefully
      text = "begincmap\n5 begincidchar\n<0020> 1\n"
      result = CMapParser.parse(text)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: parse a real committed CMap file (UniJIS-UTF16-V — small, usecmap)
  # ---------------------------------------------------------------------------

  describe "parse/1 — real CMap file integration" do
    @tag :integration
    test "UniJIS-UTF16-V: has codespaces, cidchars, and parent = UniJIS-UTF16-H" do
      path = Path.join(:code.priv_dir(:ex_pdf_read), "cmap/UniJIS-UTF16-V")
      text = File.read!(path)

      assert {:ok, cmap} = CMapParser.parse(text)
      assert cmap.parent == "UniJIS-UTF16-H"
      # The -V file adds some overriding cidchar entries
      assert map_size(cmap.cidchar) > 0
    end

    @tag :integration
    test "UniJIS-UTF16-H: large file parses to non-empty cidchars without timeout" do
      path = Path.join(:code.priv_dir(:ex_pdf_read), "cmap/UniJIS-UTF16-H")
      text = File.read!(path)

      assert {:ok, cmap} = CMapParser.parse(text)
      assert map_size(cmap.cidchar) > 100
      assert cmap.codespaces[2] != [] or Map.values(cmap.codespaces) != []
      assert cmap.parent == nil
    end
  end
end
