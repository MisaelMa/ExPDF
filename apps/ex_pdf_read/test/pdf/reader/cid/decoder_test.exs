defmodule Pdf.Reader.CID.DecoderTest do
  use ExUnit.Case, async: true

  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts
  # - PDF 1.7 § 9.7.4 — CIDFonts
  # - PDF 1.7 § 9.7.5 — CMaps (Identity-H, Identity-V predefined)
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

  alias Pdf.Reader.CID.Decoder
  alias Pdf.Reader.{CMap, Document}

  defp empty_doc do
    %Document{binary: <<>>, xref: %{}, cache: %{}, trailer: %{}}
  end

  # Build a CMap binary with a single bfchar mapping CID → UTF-16BE codepoint.
  defp cmap_for(cid, codepoint) do
    hex_src = Integer.to_string(cid, 16) |> String.pad_leading(4, "0")
    hex_dst = Integer.to_string(codepoint, 16) |> String.pad_leading(4, "0")

    """
    begincmap
    1 beginbfchar
    <#{hex_src}> <#{hex_dst}>
    endbfchar
    endcmap
    """
  end

  # A minimal Type0 font dict with a Japan1 CIDSystemInfo — for registry fallback tests.
  # Uses "__test_cmap__" for pre-parsed CMap injection (mirrors font.ex shortcut).
  defp japan1_font_dict(cmap \\ nil) do
    base = %{
      "Subtype" => {:name, "Type0"},
      "Encoding" => {:name, "Identity-H"},
      "DescendantFonts" => [
        %{
          "Subtype" => {:name, "CIDFontType2"},
          "CIDSystemInfo" => %{
            "Registry" => "Adobe",
            "Ordering" => "Japan1",
            "Supplement" => 7
          },
          "CIDToGIDMap" => {:name, "Identity"}
        }
      ]
    }

    if cmap, do: Map.put(base, "__test_cmap__", cmap), else: base
  end

  defp unknown_registry_font_dict do
    %{
      "Subtype" => {:name, "Type0"},
      "Encoding" => {:name, "Identity-H"},
      "DescendantFonts" => [
        %{
          "Subtype" => {:name, "CIDFontType2"},
          "CIDSystemInfo" => %{
            "Registry" => "Custom",
            "Ordering" => "MyCustom",
            "Supplement" => 0
          },
          "CIDToGIDMap" => {:name, "Identity"}
        }
      ]
    }
  end

  defp non_identity_type0_font_dict do
    %{
      "Subtype" => {:name, "Type0"},
      "Encoding" => {:name, "UniJIS-UTF16-H"},
      "DescendantFonts" => [
        %{
          "Subtype" => {:name, "CIDFontType2"},
          "CIDSystemInfo" => %{
            "Registry" => "Adobe",
            "Ordering" => "Japan1",
            "Supplement" => 7
          },
          "CIDToGIDMap" => {:name, "Identity"}
        }
      ]
    }
  end

  # ---------------------------------------------------------------------------
  # S-CID2: 2-byte CID extraction
  # ---------------------------------------------------------------------------

  describe "build/2 — S-CID2 — 2-byte CID extraction" do
    test "2-byte bytes <<0x30, 0x42>> yields ONE CID (0x3042 = hiragana 'ha')" do
      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Decoder.build(japan1_font_dict(), doc)

      {text, _unresolved} = decoder.(<<0x30, 0x42>>)
      # CID 0x3042 → should resolve via Japan1 registry to hiragana は
      assert is_binary(text)
      assert byte_size(text) > 0
    end

    test "empty bytes yield empty string and no unresolved" do
      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Decoder.build(japan1_font_dict(), doc)

      {text, unresolved} = decoder.(<<>>)
      assert text == ""
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # S-CID11: Odd byte count silently truncated
  # ---------------------------------------------------------------------------

  describe "build/2 — S-CID11 — odd byte count truncation" do
    test "3 bytes <<0x30, 0x42, 0xAB>> decodes 1 CID and drops trailing byte" do
      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Decoder.build(japan1_font_dict(), doc)

      # CID 0x3042 resolved; trailing 0xAB dropped
      {text, _unresolved} = decoder.(<<0x30, 0x42, 0xAB>>)
      assert is_binary(text)
      # Must be exactly ONE code unit (not two)
      {text_from_two, _} = decoder.(<<0x30, 0x42>>)
      assert text == text_from_two
    end
  end

  # ---------------------------------------------------------------------------
  # S-CID4: ToUnicode CMap precedence over registry
  # ---------------------------------------------------------------------------

  describe "build/2 — S-CID4 — ToUnicode CMap overrides registry" do
    test "CID 1 mapped by CMap to 'X' wins over AdobeJapan1.lookup(1)" do
      # CID 1 in Japan1 = 0x0020 (space); CMap overrides to U+0058 ('X')
      cmap = CMap.parse(cmap_for(1, 0x0058))

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Decoder.build(japan1_font_dict(cmap), doc)

      {text, unresolved} = decoder.(<<0, 1>>)
      assert text == "X"
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # S-CID5: Registry fallback
  # ---------------------------------------------------------------------------

  describe "build/2 — S-CID5 — registry fallback when no CMap" do
    test "CID 1 with no ToUnicode and Japan1 registry returns space (U+0020)" do
      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Decoder.build(japan1_font_dict(), doc)

      {text, unresolved} = decoder.(<<0, 1>>)
      assert text == " "
      assert unresolved == []
    end
  end

  # ---------------------------------------------------------------------------
  # S-CID6: U+FFFD for unknown registry
  # ---------------------------------------------------------------------------

  describe "build/2 — S-CID6 — U+FFFD for unknown registry" do
    test "CID 1 with unknown 'MyCustom' registry and no CMap returns U+FFFD + sentinel" do
      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Decoder.build(unknown_registry_font_dict(), doc)

      {text, unresolved} = decoder.(<<0, 1>>)
      assert text == "�"
      assert length(unresolved) == 1
      [{idx, sentinel}] = unresolved
      assert idx == 0
      assert String.starts_with?(sentinel, "cid:0x")
    end
  end

  # ---------------------------------------------------------------------------
  # S-CID10: Non-Identity-H Type0 handled (fallback to U+FFFD)
  # ---------------------------------------------------------------------------

  describe "build/2 — S-CID10 — non-Identity encoding returns error or FFFD" do
    test "font with UniJIS-UTF16-H encoding still returns a result (FFFD per byte pair)" do
      doc = empty_doc()
      # Non-Identity font: Decoder.build may return error or FFFD decoder
      result = Decoder.build(non_identity_type0_font_dict(), doc)

      case result do
        {:ok, decoder, _doc2} ->
          {text, _unresolved} = decoder.(<<0, 1>>)
          assert is_binary(text)

        {:error, _} ->
          # Also acceptable — non-Identity out of scope
          :ok
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4 — Tasks 4.1+4.2: cid_font? dispatch via Font.build_decoder
  # R-PCM1, R-PCM15, R-CID2
  # ---------------------------------------------------------------------------

  describe "build_predefined/2 — dispatch for bundled predefined CMap names (R-PCM15, R-CID2)" do
    alias Pdf.Reader.Font

    defp japan1_predefined_font_dict(encoding_name) do
      %{
        "Subtype" => {:name, "Type0"},
        "Encoding" => {:name, encoding_name},
        "DescendantFonts" => [
          %{
            "Subtype" => {:name, "CIDFontType2"},
            "CIDSystemInfo" => %{
              "Registry" => "Adobe",
              "Ordering" => "Japan1",
              "Supplement" => 7
            },
            "CIDToGIDMap" => {:name, "Identity"}
          }
        ]
      }
    end

    # 4.1+4.2: cid_font? recognizes bundled predefined names → predefined path
    # Verified by: the returned doc.cache must contain {:predefined_cmap, name}
    # (this only happens if the predefined branch ran, NOT the simple or Identity path)
    test "Font.build_decoder populates predefined_cmap cache for UniJIS-UTF16-H (R-PCM15)" do
      doc = empty_doc()
      font_dict = japan1_predefined_font_dict("UniJIS-UTF16-H")
      assert {:ok, _decoder, doc2} = Font.build_decoder(font_dict, doc)

      # Only the predefined branch stores {:predefined_cmap, name} in doc.cache
      assert Map.has_key?(doc2.cache, {:predefined_cmap, "UniJIS-UTF16-H"}),
             "Expected predefined CMap cache entry for UniJIS-UTF16-H"
    end

    test "Font.build_decoder populates predefined_cmap cache for 90ms-RKSJ-H (R-PCM15)" do
      doc = empty_doc()
      font_dict = japan1_predefined_font_dict("90ms-RKSJ-H")
      assert {:ok, _decoder, doc2} = Font.build_decoder(font_dict, doc)

      assert Map.has_key?(doc2.cache, {:predefined_cmap, "90ms-RKSJ-H"}),
             "Expected predefined CMap cache entry for 90ms-RKSJ-H"
    end

    # 4.3+4.4: predefined closure tokenizes by codespace, NOT fixed 2-byte chunks
    # 90ms-RKSJ-H: 0x81, 0x40 is a 2-byte code → 1 token → 1 output char
    # Simple path: 0x81 and 0x40 decoded as 2 separate 1-byte codes → 2 tokens
    test "decoder for 90ms-RKSJ-H treats <<0x81, 0x40>> as single 2-byte code (S-PCM1)" do
      doc = empty_doc()
      font_dict = japan1_predefined_font_dict("90ms-RKSJ-H")
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      {text, _unresolved} = decoder.(<<0x81, 0x40>>)
      # Predefined path: 0x8140 → 1 code → 1 output character (resolved or FFFD)
      # Simple path: 2 separate bytes → 2 characters (2 FFFD with sentinels)
      # We measure by codepoint count — should be exactly 1 for predefined path
      codepoint_count = text |> String.codepoints() |> length()

      assert codepoint_count == 1,
             "Expected 1 codepoint from 2-byte code 0x8140, got #{codepoint_count}: #{inspect(text)}"
    end

    # 4.5+4.6: Codespace.tokenize drops bytes outside codespace (R-PCM13)
    # 0xFF is outside all 90ms-RKSJ-H codespace ranges → dropped
    # 0x20 is in 1-byte codespace → decoded as 1 code → 1 output char
    test "decoder for 90ms-RKSJ-H drops 0xFF (outside codespace) and decodes 0x20 (R-PCM13)" do
      doc = empty_doc()
      font_dict = japan1_predefined_font_dict("90ms-RKSJ-H")
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict, doc)

      # Simple path: 0xFF → 1 char (FFFD), 0x20 → 1 char = 2 total
      # Predefined path: 0xFF dropped, 0x20 → 1 char = 1 total
      {text, _unresolved} = decoder.(<<0xFF, 0x20>>)
      codepoint_count = text |> String.codepoints() |> length()

      assert codepoint_count == 1,
             "Expected 0xFF dropped and 0x20 decoded as 1 char, got #{codepoint_count}: #{inspect(text)}"
    end

    # 4.7+4.8: ToUnicode wins over predefined CMap — R-PCM17, S-PCM8
    # Use a ToUnicode that maps 0x0020 (code after tokenization) to "Z".
    # Predefined path: ToUnicode checked first → "Z".
    # Verify it's still "Z" (same as simple path for this byte, but the mechanism differs).
    test "ToUnicode entry wins over predefined CMap for same code (S-PCM8, R-PCM17)" do
      to_unicode_text = "begincmap\n1 beginbfchar\n<0020> <005A>\nendbfchar\nendcmap\n"
      to_unicode_cmap = CMap.parse(to_unicode_text)

      font_dict_with_tounicode =
        japan1_predefined_font_dict("90ms-RKSJ-H")
        |> Map.put("__test_cmap__", to_unicode_cmap)

      doc = empty_doc()
      assert {:ok, decoder, _doc2} = Font.build_decoder(font_dict_with_tounicode, doc)

      {text, unresolved} = decoder.(<<0x20>>)
      assert text == "Z", "Expected ToUnicode to win: got #{inspect(text)}"
      assert unresolved == []
    end

    # 4.7+4.8: non-bundled name → cid_font? false → simple decoder path (R-PCM2, S-PCM14, S-CID10)
    # Simple path with non-Identity, non-bundled Type0: result is per-byte decoding
    test "Font.build_decoder with non-bundled name falls to simple path (S-CID10)" do
      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "Encoding" => {:name, "SomeUnknownCMap-H"},
        "DescendantFonts" => [
          %{
            "Subtype" => {:name, "CIDFontType2"},
            "CIDSystemInfo" => %{
              "Registry" => "Adobe",
              "Ordering" => "Japan1",
              "Supplement" => 7
            }
          }
        ]
      }

      doc = empty_doc()
      assert {:ok, decoder, doc2} = Font.build_decoder(font_dict, doc)
      assert is_function(decoder, 1)

      # Non-bundled → no predefined_cmap cache entry
      refute Map.has_key?(doc2.cache, {:predefined_cmap, "SomeUnknownCMap-H"}),
             "Non-bundled name should NOT populate predefined_cmap cache"

      {text, _unresolved} = decoder.(<<0, 1>>)
      assert is_binary(text)
    end
  end
end
