defmodule Pdf.Reader.CMapTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.CMap

  # Spec reference: PDF 1.7 § 9.10.3 and Adobe Tech Note 5099
  # Control points for bfchar: hand-crafted CMap snippets per spec syntax.
  # Unicode values verified against Unicode chart (U+0041 = Latin A, etc.)

  # ---- 7.1.1 parse/1 — bfchar section ----

  describe "parse/1 bfchar" do
    test "parses single bfchar mapping (1-byte src → UTF-16BE dst)" do
      # <41> → U+0041 (LATIN CAPITAL LETTER A)
      # UTF-16BE for U+0041 is <<0x00, 0x41>>
      cmap_bin = """
      /CIDInit /ProcSet findresource begin
      12 dict begin
      begincmap
      /CIDSystemInfo 3 dict dup begin
        /Registry (Adobe) def
        /Ordering (UCS) def
        /Supplement 0 def
      end def
      /CMapName /Adobe-Identity-UCS def
      1 beginbfchar
      <41> <0041>
      endbfchar
      endcmap
      CMapName currentdict /CMap defineresource pop
      end
      end
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "A"
    end

    test "parses multiple bfchar mappings" do
      # <48> → U+0048 (H), <65> → U+0065 (e), <6C> → U+006C (l)
      cmap_bin = """
      begincmap
      3 beginbfchar
      <48> <0048>
      <65> <0065>
      <6C> <006C>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x48) == "H"
      assert CMap.lookup(cmap, 0x65) == "e"
      assert CMap.lookup(cmap, 0x6C) == "l"
    end

    test "handles 2-byte src code in bfchar" do
      # 2-byte source code <0020> → U+0020 (SPACE)
      cmap_bin = """
      begincmap
      1 beginbfchar
      <0020> <0020>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x0020) == " "
    end

    test "handles multi-codepoint dst (ligature) in bfchar" do
      # <FB00> → UTF-16BE: U+FB00 (LATIN SMALL LIGATURE FF)
      # Some CMaps map a single code to a multi-char sequence; e.g. ff → "ff"
      # <FB01> → U+0066 U+0069 (f + i) — two UTF-16BE codepoints in one hex string
      cmap_bin = """
      begincmap
      1 beginbfchar
      <FB01> <00660069>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      # Should decode to "fi" (f=U+0066, i=U+0069)
      assert CMap.lookup(cmap, 0xFB01) == "fi"
    end

    test "lookup returns nil for unmapped code" do
      cmap_bin = """
      begincmap
      1 beginbfchar
      <41> <0041>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x42) == nil
    end
  end

  # ---- 7.1.2 parse/1 — bfrange string-base form ----

  describe "parse/1 bfrange string-base form" do
    test "maps consecutive codes starting from dst base" do
      # Range <41>..<43> → start at U+0041
      # So: 0x41→"A", 0x42→"B", 0x43→"C"
      cmap_bin = """
      begincmap
      1 beginbfrange
      <41> <43> <0041>
      endbfrange
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "A"
      assert CMap.lookup(cmap, 0x42) == "B"
      assert CMap.lookup(cmap, 0x43) == "C"
    end

    test "maps code outside range to nil" do
      cmap_bin = """
      begincmap
      1 beginbfrange
      <41> <43> <0041>
      endbfrange
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x40) == nil
      assert CMap.lookup(cmap, 0x44) == nil
    end
  end

  # ---- 7.1.3 parse/1 — bfrange array form ----

  describe "parse/1 bfrange array form" do
    test "maps each code in range to its corresponding array element" do
      # <41>..<43> → [<0061> <0062> <0063>]
      # 0x41→"a", 0x42→"b", 0x43→"c"
      cmap_bin = """
      begincmap
      1 beginbfrange
      <41> <43> [<0061> <0062> <0063>]
      endbfrange
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "a"
      assert CMap.lookup(cmap, 0x42) == "b"
      assert CMap.lookup(cmap, 0x43) == "c"
    end

    test "array element out of bounds returns nil" do
      # Range <41>..<41> (single) with array [<0061>]
      cmap_bin = """
      begincmap
      1 beginbfrange
      <41> <41> [<0061>]
      endbfrange
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "a"
      assert CMap.lookup(cmap, 0x42) == nil
    end
  end

  # ---- 7.1.4 parse/1 — bfchar takes priority over bfrange ----

  describe "lookup priority: bfchar over bfrange" do
    test "bfchar overrides a range that would also match" do
      # Range maps 0x41→"A"; bfchar maps 0x41→"Z"
      # bfchar must win
      cmap_bin = """
      begincmap
      1 beginbfrange
      <41> <43> <0041>
      endbfrange
      1 beginbfchar
      <41> <005A>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      # 0x005A = Z
      assert CMap.lookup(cmap, 0x41) == "Z"
      # 0x42 still from range → "B"
      assert CMap.lookup(cmap, 0x42) == "B"
    end
  end

  # ---- 7.1.5 parse/1 — multiple sections ----

  describe "parse/1 multiple sections" do
    test "combines entries from multiple beginbfchar sections" do
      cmap_bin = """
      begincmap
      1 beginbfchar
      <41> <0041>
      endbfchar
      1 beginbfchar
      <42> <0042>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "A"
      assert CMap.lookup(cmap, 0x42) == "B"
    end

    test "combines entries from mixed bfchar and bfrange sections" do
      cmap_bin = """
      begincmap
      1 beginbfchar
      <61> <0061>
      endbfchar
      1 beginbfrange
      <41> <42> <0041>
      endbfrange
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "A"
      assert CMap.lookup(cmap, 0x42) == "B"
      assert CMap.lookup(cmap, 0x61) == "a"
    end
  end

  # ---- 7.1.6 parse/1 — skips unknown CMap sections ----

  describe "parse/1 unknown sections skipped" do
    test "silently skips begincodespacerange section" do
      cmap_bin = """
      begincmap
      1 begincodespacerange
      <00> <FF>
      endcodespacerange
      1 beginbfchar
      <41> <0041>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      assert CMap.lookup(cmap, 0x41) == "A"
    end

    test "silently skips begincidchar section" do
      cmap_bin = """
      begincmap
      1 begincidchar
      <41> 65
      endcidchar
      2 beginbfchar
      <41> <0041>
      <42> <0042>
      endbfchar
      endcmap
      """

      cmap = CMap.parse(cmap_bin)
      # CID mapping must not pollute bfchar
      assert CMap.lookup(cmap, 0x41) == "A"
      assert CMap.lookup(cmap, 0x42) == "B"
    end
  end
end
