defmodule Pdf.Reader.Font.WidthsTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Font.Widths
  alias Pdf.Reader.Document

  # Spec references:
  # - PDF 1.7 § 9.6.2.1 — Simple Font Width Arrays (/Widths, /FirstChar, /LastChar)
  # - PDF 1.7 § 9.6.4   — Font Descriptors (/MissingWidth)
  # - PDF 1.7 § 9.7.4.3 — CIDFont /W and /DW arrays

  # ---------------------------------------------------------------------------
  # Helper: minimal document for tests that don't need object resolution
  # ---------------------------------------------------------------------------

  defp empty_doc do
    %Document{binary: <<>>, xref: %{}, cache: %{}, trailer: %{}}
  end

  # ---------------------------------------------------------------------------
  # 1.3 parse_simple/2 — simple font width lookup
  # Spec: § 9.6.2.1, § 9.6.4
  # ---------------------------------------------------------------------------

  describe "parse_simple/2" do
    test "glyph code within /Widths range returns correct width" do
      # FirstChar=32, LastChar=126, 95 entries (all 500 except index 33 = 600 for code 65 = 'A')
      widths = List.duplicate(500, 95) |> List.replace_at(33, 600)

      font_dict = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => widths
      }

      {widths_fn, _doc} = Widths.parse_simple(font_dict, empty_doc())

      # Code 65 - 32 = index 33 → 600
      assert widths_fn.(<<65>>) == [600]
    end

    test "glyph code below FirstChar returns MissingWidth" do
      font_dict = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => List.duplicate(500, 95),
        "FontDescriptor" => %{"MissingWidth" => 500}
      }

      {widths_fn, _doc} = Widths.parse_simple(font_dict, empty_doc())

      # Code 10 is below FirstChar=32 → MissingWidth=500
      assert widths_fn.(<<10>>) == [500]
    end

    test "glyph code above LastChar returns MissingWidth" do
      font_dict = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => List.duplicate(500, 95),
        "FontDescriptor" => %{"MissingWidth" => 250}
      }

      {widths_fn, _doc} = Widths.parse_simple(font_dict, empty_doc())

      # Code 200 is above LastChar=126 → MissingWidth=250
      assert widths_fn.(<<200>>) == [250]
    end

    test "absent FontDescriptor returns 0 for out-of-range code" do
      font_dict = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => List.duplicate(500, 95)
        # No FontDescriptor key
      }

      {widths_fn, _doc} = Widths.parse_simple(font_dict, empty_doc())

      assert widths_fn.(<<10>>) == [0]
    end

    test "multiple bytes return list of widths" do
      widths = List.duplicate(400, 95)

      font_dict = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => widths
      }

      {widths_fn, _doc} = Widths.parse_simple(font_dict, empty_doc())

      # Three in-range bytes → three widths
      assert widths_fn.(<<32, 33, 34>>) == [400, 400, 400]
    end
  end

  # ---------------------------------------------------------------------------
  # 1.5 parse_cid/2 — CIDFont width lookup
  # Spec: § 9.7.4.3
  # ---------------------------------------------------------------------------

  describe "parse_cid/2" do
    test "Form A entry: DescendantFonts[0] with /W Form A" do
      # W: [100 [600 750 500]] — CID 100→600, 101→750, 102→500
      cid_dict = %{"W" => [100, [600, 750, 500]], "DW" => 1000}

      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "DescendantFonts" => [cid_dict]
      }

      {widths_fn, _doc} = Widths.parse_cid(font_dict, empty_doc())

      # CID 101 = byte sequence <<0x00, 0x65>>
      assert widths_fn.(<<0x00, 0x65>>) == [750]
    end

    test "Form B range in /W" do
      # W: [200 250 400] — CIDs 200..250 → 400
      cid_dict = %{"W" => [200, 250, 400], "DW" => 1000}

      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "DescendantFonts" => [cid_dict]
      }

      {widths_fn, _doc} = Widths.parse_cid(font_dict, empty_doc())

      # CID 225 = <<0x00, 0xE1>>
      assert widths_fn.(<<0x00, 0xE1>>) == [400]
    end

    test "/DW fallback for CID not in /W" do
      cid_dict = %{"W" => [10, [600]], "DW" => 800}

      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "DescendantFonts" => [cid_dict]
      }

      {widths_fn, _doc} = Widths.parse_cid(font_dict, empty_doc())

      # CID 99 = <<0x00, 0x63>> — not in /W → DW=800
      assert widths_fn.(<<0x00, 0x63>>) == [800]
    end

    test "absent /DW defaults to 1000" do
      cid_dict = %{"W" => [10, [600]]}
      # No DW key

      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "DescendantFonts" => [cid_dict]
      }

      {widths_fn, _doc} = Widths.parse_cid(font_dict, empty_doc())

      # CID 99 = <<0x00, 0x63>> — not in /W → default DW=1000
      assert widths_fn.(<<0x00, 0x63>>) == [1000]
    end

    test "multiple 2-byte pairs return list of widths" do
      cid_dict = %{"W" => [1, [600, 700, 800]], "DW" => 1000}

      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "DescendantFonts" => [cid_dict]
      }

      {widths_fn, _doc} = Widths.parse_cid(font_dict, empty_doc())

      # CID 1 = <<0,1>>, CID 2 = <<0,2>>, CID 3 = <<0,3>>
      assert widths_fn.(<<0, 1, 0, 2, 0, 3>>) == [600, 700, 800]
    end
  end

  # ---------------------------------------------------------------------------
  # 1.7 build_widths_fn/2 — closure contract and cache
  # ---------------------------------------------------------------------------

  describe "build_widths_fn/2" do
    test "simple font closure returns list of widths for binary input" do
      widths = List.duplicate(500, 95) |> List.replace_at(33, 700)

      font_dict = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => widths
      }

      assert {:ok, widths_fn, _doc} = Widths.build_widths_fn(font_dict, empty_doc())
      # Code 65 (idx 33) → 700
      assert widths_fn.(<<65>>) == [700]
    end

    test "CID font closure returns list (2 bytes → 1 width)" do
      cid_dict = %{"W" => [1, [600, 700]], "DW" => 1000}

      font_dict = %{
        "Subtype" => {:name, "Type0"},
        "DescendantFonts" => [cid_dict]
      }

      assert {:ok, widths_fn, _doc} = Widths.build_widths_fn(font_dict, empty_doc())
      # <<0, 1>> = CID 1 → 600; <<0, 2>> = CID 2 → 700
      assert widths_fn.(<<0, 1, 0, 2>>) == [600, 700]
    end

    test "cache hit on same {:ref, n, g} returns same closure without re-parsing" do
      # First call builds and caches; second call should return the cached closure.
      # We verify by using a document with a pre-populated cache entry.
      widths_fn_stub = fn _bytes -> [999] end
      cache_key = {:font_widths, {1, 0}}

      doc_with_cache = %Document{
        binary: <<>>,
        xref: %{},
        cache: %{cache_key => widths_fn_stub},
        trailer: %{}
      }

      # Should return the cached closure, not build a new one
      assert {:ok, ^widths_fn_stub, _doc} = Widths.build_widths_fn({:ref, 1, 0}, doc_with_cache)
    end
  end

  # ---------------------------------------------------------------------------
  # 1.9 build_widths_for_resources/2 — map of resource dicts → map of closures
  # ---------------------------------------------------------------------------

  describe "build_widths_for_resources/2" do
    test "returns map of closures keyed by font name" do
      font_dict_f1 = %{
        "Subtype" => {:name, "Type1"},
        "FirstChar" => 32,
        "LastChar" => 126,
        "Widths" => List.duplicate(600, 95)
      }

      resources = %{
        "Font" => %{"F1" => font_dict_f1}
      }

      assert {:ok, widths_map, _doc} = Widths.build_widths_for_resources(resources, empty_doc())
      assert Map.has_key?(widths_map, "F1")
      # The closure for F1 should return 600 for any in-range glyph
      assert widths_map["F1"].(<<65>>) == [600]
    end

    test "font without /Widths produces zero-list closure" do
      # A font dict with no Widths/FirstChar/LastChar — all codes return 0
      font_dict = %{"Subtype" => {:name, "Type1"}}

      resources = %{"Font" => %{"F2" => font_dict}}

      assert {:ok, widths_map, _doc} = Widths.build_widths_for_resources(resources, empty_doc())
      assert Map.has_key?(widths_map, "F2")
      # No widths → missing width = 0
      assert widths_map["F2"].(<<65>>) == [0]
    end

    test "empty resources Font map returns empty widths map" do
      resources = %{"Font" => %{}}
      assert {:ok, widths_map, _doc} = Widths.build_widths_for_resources(resources, empty_doc())
      assert widths_map == %{}
    end

    test "resources without Font key returns empty widths map" do
      resources = %{}
      assert {:ok, widths_map, _doc} = Widths.build_widths_for_resources(resources, empty_doc())
      assert widths_map == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # 1.1 parse_w_array/1 — Form A: c [w1 w2 …]
  # ---------------------------------------------------------------------------

  describe "parse_w_array/1 — Form A (explicit list)" do
    test "single entry maps CID 100 to [600, 750, 500]" do
      # Form A: [100 [600 750 500]]
      # CID 100 → 600, CID 101 → 750, CID 102 → 500
      w_array = [100, [600, 750, 500]]
      result = Widths.parse_w_array(w_array)

      assert result[100] == 600
      assert result[101] == 750
      assert result[102] == 500
    end

    test "multiple Form-A entries are all present" do
      # [10 [100 200] 20 [300 400]]
      w_array = [10, [100, 200], 20, [300, 400]]
      result = Widths.parse_w_array(w_array)

      assert result[10] == 100
      assert result[11] == 200
      assert result[20] == 300
      assert result[21] == 400
    end
  end

  # ---------------------------------------------------------------------------
  # 1.1 parse_w_array/1 — Form B: c1 c2 w
  # ---------------------------------------------------------------------------

  describe "parse_w_array/1 — Form B (range with uniform width)" do
    test "range 200..250 all map to 400" do
      # Form B: [200 250 400]
      w_array = [200, 250, 400]
      result = Widths.parse_w_array(w_array)

      assert result[200] == 400
      assert result[225] == 400
      assert result[250] == 400
      # Outside the range → not present
      refute Map.has_key?(result, 251)
      refute Map.has_key?(result, 199)
    end

    test "single-CID range (c1 == c2)" do
      w_array = [50, 50, 800]
      result = Widths.parse_w_array(w_array)

      assert result[50] == 800
      refute Map.has_key?(result, 51)
    end
  end

  # ---------------------------------------------------------------------------
  # 1.1 parse_w_array/1 — Interleaved Form A and Form B
  # ---------------------------------------------------------------------------

  describe "parse_w_array/1 — interleaved Form A and Form B" do
    test "Form A followed by Form B" do
      # [10 [600 700] 20 25 500]
      # Form A: CID 10 → 600, CID 11 → 700
      # Form B: CIDs 20..25 → 500
      w_array = [10, [600, 700], 20, 25, 500]
      result = Widths.parse_w_array(w_array)

      # Form A part
      assert result[10] == 600
      assert result[11] == 700
      # Form B part
      assert result[20] == 500
      assert result[22] == 500
      assert result[25] == 500
      # Not present
      refute Map.has_key?(result, 12)
      refute Map.has_key?(result, 26)
    end

    test "Form B followed by Form A" do
      # [5 7 300 20 [400 500 600]]
      w_array = [5, 7, 300, 20, [400, 500, 600]]
      result = Widths.parse_w_array(w_array)

      assert result[5] == 300
      assert result[6] == 300
      assert result[7] == 300
      assert result[20] == 400
      assert result[21] == 500
      assert result[22] == 600
    end
  end

  # ---------------------------------------------------------------------------
  # 1.1 parse_w_array/1 — Edge cases
  # ---------------------------------------------------------------------------

  describe "parse_w_array/1 — edge cases" do
    test "empty list returns empty map" do
      result = Widths.parse_w_array([])
      assert result == %{}
    end

    test "odd-length malformed input (trailing integer) is handled gracefully" do
      # [100 200 400 50] — the trailing 50 has no pair → ignored
      w_array = [100, 200, 400, 50]
      result = Widths.parse_w_array(w_array)

      # The valid Form B [100 200 400] should still parse
      assert result[100] == 400
      assert result[150] == 400
      assert result[200] == 400
      # The dangling 50 should not crash
    end
  end
end
