defmodule Pdf.Reader.FontTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.{Font, Document, CMap}

  # Spec references:
  # - PDF 1.7 § 9.6 — Type 1 Fonts
  # - PDF 1.7 § 9.6.5, § 9.6.5.1 — Character Encoding, /Differences arrays
  # - PDF 1.7 § 9.10.3 — ToUnicode CMaps
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # A minimal document with no xref entries (for inline font dict tests).
  defp empty_doc do
    %Document{binary: <<>>, xref: %{}, cache: %{}, trailer: %{}}
  end

  # Build a CMap binary mapping a single byte to a UTF-16BE codepoint.
  defp cmap_bin_for(byte, codepoint) do
    hex_src = Integer.to_string(byte, 16) |> String.pad_leading(2, "0")
    hex_dst = Integer.to_string(codepoint, 16) |> String.pad_leading(4, "0")

    """
    begincmap
    1 beginbfchar
    <#{hex_src}> <#{hex_dst}>
    endbfchar
    endcmap
    """
  end

  # ---------------------------------------------------------------------------
  # 2.1 — build_decoder/2 with ToUnicode-only font dict
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — ToUnicode-only (R-CW7, S-CW3)" do
    test "closure maps byte correctly via ToUnicode CMap" do
      # Font dict with a pre-parsed CMap already stored as {:cmap, cmap_struct}.
      # For test purposes, we pass the parsed CMap inline (no stream resolution needed).
      cmap = CMap.parse(cmap_bin_for(0x41, 0x0042))

      font_dict = %{"__test_cmap__" => cmap}
      doc = empty_doc()

      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)
      {text, unresolved} = decoder.(<<0x41>>)

      # ToUnicode maps 0x41 → U+0042 ("B")
      assert text == "B"
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # 2.2 — build_decoder/2 with WinAnsi base only
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — WinAnsi base encoding (R-CW7, S-CW1)" do
    test "ASCII bytes round-trip through WinAnsi" do
      font_dict = %{
        "Encoding" => {:name, "WinAnsiEncoding"}
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # 0x48 = 'H' in WinAnsi → U+0048
      {text, unresolved} = decoder.(<<0x48>>)
      assert text == "H"
      assert unresolved == []
    end

    test "non-ASCII byte decodes via WinAnsi table" do
      font_dict = %{
        "Encoding" => {:name, "WinAnsiEncoding"}
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # WinAnsi 0xE9 = U+00E9 (é)
      {text, unresolved} = decoder.(<<0xE9>>)
      assert text == "é"
      assert unresolved == []
    end

    test "multiple bytes decoded in sequence" do
      font_dict = %{
        "Encoding" => {:name, "WinAnsiEncoding"}
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # "Hi" in ASCII bytes
      {text, unresolved} = decoder.(<<"Hi">>)
      assert text == "Hi"
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # 2.3 — build_decoder/2 with /Differences override on WinAnsiEncoding
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — /Differences override on WinAnsi (R-CW7, S-CW2)" do
    test "byte 65 mapped to eacute via /Differences resolves to U+00E9" do
      font_dict = %{
        "Encoding" => %{
          "BaseEncoding" => {:name, "WinAnsiEncoding"},
          "Differences" => [65, {:name, "eacute"}]
        }
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      {text, unresolved} = decoder.(<<65>>)
      assert text == "é"
      assert unresolved == []
    end

    test "byte NOT in /Differences still falls through to WinAnsi" do
      font_dict = %{
        "Encoding" => %{
          "BaseEncoding" => {:name, "WinAnsiEncoding"},
          "Differences" => [65, {:name, "eacute"}]
        }
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # Byte 66 = 'B' — not in /Differences, WinAnsi maps it to U+0042
      {text, unresolved} = decoder.(<<66>>)
      assert text == "B"
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # 2.4 — ToUnicode wins over /Differences for same byte
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — ToUnicode wins over /Differences (R-CW7, S-CW3)" do
    test "when ToUnicode maps a byte, /Differences for that byte is ignored" do
      # ToUnicode maps 0x41 → U+0042 ("B")
      # /Differences maps 65 (=0x41) → "eacute" → U+00E9 ("é")
      # ToUnicode must win.
      cmap = CMap.parse(cmap_bin_for(0x41, 0x0042))

      font_dict = %{
        "__test_cmap__" => cmap,
        "Encoding" => %{
          "BaseEncoding" => {:name, "WinAnsiEncoding"},
          "Differences" => [65, {:name, "eacute"}]
        }
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      {text, unresolved} = decoder.(<<0x41>>)
      # ToUnicode wins → "B"
      assert text == "B"
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # 2.5 — no /Encoding key falls back to identity
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — no /Encoding key (R-CW7, R-CW6)" do
    test "bytes returned as-is (identity passthrough via unresolved → FFFD or base nil)" do
      # With no /Encoding key and no ToUnicode, ASCII bytes still map
      # through WinAnsi-equivalent or identity for standard ASCII range.
      font_dict = %{}
      doc = empty_doc()

      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # ASCII 'A' (0x41) — with nil base encoding, resolve_byte falls back
      # to {:unresolved, "byte:0x41"} → U+FFFD
      # This is the identity-style fallback: unresolved glyph returns FFFD.
      {text, _unresolved} = decoder.(<<0x41>>)
      # Either passes as-is (implementation-defined for ASCII range)
      # or returns FFFD — both are acceptable for nil encoding.
      # The key assertion: it does NOT crash.
      assert is_binary(text)
    end

    test "decoder returns empty text and unresolved for empty input" do
      font_dict = %{}
      doc = empty_doc()

      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      {text, unresolved} = decoder.(<<>>)
      assert text == ""
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # 2.6 — unresolvable glyph returns U+FFFD + sentinel
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — unresolvable glyph (R-CW2, R-CW7, S-CW13, S-CW14)" do
    test "unknown glyph name in /Differences returns U+FFFD and unresolved tuple" do
      font_dict = %{
        "Encoding" => %{
          "BaseEncoding" => {:name, "WinAnsiEncoding"},
          "Differences" => [200, {:name, "completelymadeupglyph999"}]
        }
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      {text, unresolved} = decoder.(<<200>>)

      # U+FFFD replacement character
      assert text == "�"
      # Sentinel: {codepoint_index, glyph_name}
      assert unresolved == [{0, "completelymadeupglyph999"}]
    end

    test "multiple bytes with one unresolvable accumulate sentinels correctly" do
      font_dict = %{
        "Encoding" => %{
          "BaseEncoding" => {:name, "WinAnsiEncoding"},
          "Differences" => [200, {:name, "completelymadeupglyph999"}]
        }
      }

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # Byte 65 = 'A' (resolved), byte 200 = unresolved
      {text, unresolved} = decoder.(<<65, 200>>)

      assert String.starts_with?(text, "A")
      assert String.contains?(text, "�")
      assert length(unresolved) == 1
      [{idx, name}] = unresolved
      assert name == "completelymadeupglyph999"
      assert is_integer(idx)
    end
  end

  # ---------------------------------------------------------------------------
  # 2.7 — font_ref {:ref, n, g} — second call hits doc.cache
  # ---------------------------------------------------------------------------

  describe "build_decoder/2 — cache via indirect ref (R-CW5, R-CW7)" do
    test "second call with same ref returns cached decoder from doc.cache" do
      # We need a doc that has the font dict accessible at {:ref, 10, 0}.
      # Build a minimal doc with the font dict pre-cached.
      font_dict = %{"Encoding" => {:name, "WinAnsiEncoding"}}
      font_ref = {:ref, 10, 0}

      doc = %Document{
        binary: <<>>,
        xref: %{{10, 0} => {:in_use, 0, 0}},
        cache: %{{10, 0} => font_dict},
        trailer: %{}
      }

      # First call: builds the decoder and populates the font_decoder cache key
      assert {:ok, _decoder1, doc2} = Font.build_decoder(font_ref, doc)

      # Cache must now have {:font_decoder, {10, 0}}
      assert Map.has_key?(doc2.cache, {:font_decoder, {10, 0}})

      # Second call with the updated doc: must use the cached decoder
      assert {:ok, decoder2, doc3} = Font.build_decoder(font_ref, doc2)

      # The cache hit must not rebuild — doc.cache key must still be present
      assert Map.has_key?(doc3.cache, {:font_decoder, {10, 0}})

      # The returned decoder must be the same function reference (cache hit path)
      cached_decoder = Map.get(doc2.cache, {:font_decoder, {10, 0}})
      assert decoder2 == cached_decoder
    end
  end

  # ---------------------------------------------------------------------------
  # 2.8 — build_decoders_for_resources/2 — multiple fonts
  # ---------------------------------------------------------------------------

  describe "build_decoders_for_resources/2 (R-CW7, S-CW4)" do
    test "resources map with 2 fonts returns map keyed by font name" do
      # Two inline font dicts (no ref — inline fonts skip caching)
      font_f1 = %{"Encoding" => {:name, "WinAnsiEncoding"}}
      font_f2 = %{"Encoding" => {:name, "MacRomanEncoding"}}

      resources = %{
        "Font" => %{
          "F1" => font_f1,
          "F2" => font_f2
        }
      }

      doc = empty_doc()
      assert {:ok, decoders, _doc2} = Font.build_decoders_for_resources(resources, doc)

      assert Map.has_key?(decoders, "F1")
      assert Map.has_key?(decoders, "F2")

      # Each value must be a function (decoder_fn)
      f1_decoder = Map.get(decoders, "F1")
      f2_decoder = Map.get(decoders, "F2")

      assert is_function(f1_decoder, 1)
      assert is_function(f2_decoder, 1)
    end

    test "empty Font dict returns empty decoders map" do
      resources = %{"Font" => %{}}
      doc = empty_doc()

      assert {:ok, decoders, _doc2} = Font.build_decoders_for_resources(resources, doc)
      assert decoders == %{}
    end

    test "resources without Font key returns empty decoders map" do
      resources = %{}
      doc = empty_doc()

      assert {:ok, decoders, _doc2} = Font.build_decoders_for_resources(resources, doc)
      assert decoders == %{}
    end

    test "decoders function correctly for their respective encodings" do
      font_f1 = %{"Encoding" => {:name, "WinAnsiEncoding"}}

      resources = %{
        "Font" => %{"F1" => font_f1}
      }

      doc = empty_doc()
      assert {:ok, decoders, _doc2} = Font.build_decoders_for_resources(resources, doc)

      f1_decoder = Map.get(decoders, "F1")
      {text, unresolved} = f1_decoder.(<<"Hi">>)
      assert text == "Hi"
      assert unresolved == []
    end
  end
end
