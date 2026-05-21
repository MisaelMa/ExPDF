defmodule Pdf.Reader.UtilsTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Utils

  # ---------------------------------------------------------------------------
  # Task 1.1 + 1.3 — decode_pdf_string/1 unit tests
  # Spec: R-AO25, S-AO5, S-AO20
  # PDF 1.7 § 7.9.2.2 — Text String Type (UTF-16BE BOM)
  # ---------------------------------------------------------------------------

  describe "decode_pdf_string/1" do
    @tag :unit
    test "nil → nil" do
      assert Utils.decode_pdf_string(nil) == nil
    end

    @tag :unit
    test "non-binary term → nil" do
      assert Utils.decode_pdf_string(42) == nil
      assert Utils.decode_pdf_string(:some_atom) == nil
      assert Utils.decode_pdf_string([1, 2, 3]) == nil
    end

    @tag :unit
    test "plain ASCII binary → same string returned" do
      assert Utils.decode_pdf_string("Hello") == "Hello"
      assert Utils.decode_pdf_string("PDF text") == "PDF text"
      assert Utils.decode_pdf_string("") == ""
    end

    @tag :unit
    test "valid UTF-8 binary → same string returned" do
      assert Utils.decode_pdf_string("Héllo") == "Héllo"
    end

    @tag :unit
    test "UTF-16BE BOM (0xFE 0xFF) → decoded to UTF-8 string" do
      # Encodes "Hello" as UTF-16BE with BOM
      utf16be_hello = <<0xFE, 0xFF, 0x00, 0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F>>
      assert Utils.decode_pdf_string(utf16be_hello) == "Hello"
    end

    @tag :unit
    test "UTF-16BE BOM with non-ASCII chars → decoded to UTF-8" do
      # Encodes "Ñ" (U+00D1) as UTF-16BE with BOM
      utf16be_enye = <<0xFE, 0xFF, 0x00, 0xD1>>
      assert Utils.decode_pdf_string(utf16be_enye) == "Ñ"
    end

    @tag :unit
    test "{:string, binary} tuple → decoded string (convenience branch)" do
      assert Utils.decode_pdf_string({:string, "Hello"}) == "Hello"
    end

    @tag :unit
    test "{:string, UTF-16BE binary} → decoded UTF-8 string" do
      utf16be = <<0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69>>
      assert Utils.decode_pdf_string({:string, utf16be}) == "Hi"
    end

    @tag :unit
    test "non-UTF-8 binary (no BOM) → best-effort ASCII extraction" do
      # bytes with high bits set — not valid UTF-8, no BOM
      binary = <<65, 66, 200, 67>>
      result = Utils.decode_pdf_string(binary)
      assert is_binary(result)
      # ASCII bytes preserved; non-ASCII replaced
      assert String.starts_with?(result, "AB")
    end
  end

  # ---------------------------------------------------------------------------
  # Task 1.2 + 1.4 — parse_rect/1 unit tests
  # Spec: R-AO18, R-AO25
  # ---------------------------------------------------------------------------

  describe "parse_rect/1" do
    @tag :unit
    test "nil → nil" do
      assert Utils.parse_rect(nil) == nil
    end

    @tag :unit
    test "list of 4 integers → {x1, y1, x2, y2} as floats" do
      assert Utils.parse_rect([0, 0, 100, 200]) == {0.0, 0.0, 100.0, 200.0}
    end

    @tag :unit
    test "list of 4 floats → {x1, y1, x2, y2}" do
      assert Utils.parse_rect([1.5, 2.5, 300.0, 400.0]) == {1.5, 2.5, 300.0, 400.0}
    end

    @tag :unit
    test "list of 4 mixed numbers (int + float) → {x1, y1, x2, y2} as floats" do
      assert Utils.parse_rect([10, 20.5, 300, 400.0]) == {10.0, 20.5, 300.0, 400.0}
    end

    @tag :unit
    test "list with fewer than 4 elements → nil" do
      assert Utils.parse_rect([1, 2, 3]) == nil
    end

    @tag :unit
    test "list with more than 4 elements → nil" do
      assert Utils.parse_rect([1, 2, 3, 4, 5]) == nil
    end

    @tag :unit
    test "non-list value → nil" do
      assert Utils.parse_rect("not a list") == nil
      assert Utils.parse_rect(42) == nil
      assert Utils.parse_rect({1, 2, 3, 4}) == nil
    end

    @tag :unit
    test "list of 4 with non-numeric elements → nil" do
      assert Utils.parse_rect([1, 2, "three", 4]) == nil
      assert Utils.parse_rect([1, 2, nil, 4]) == nil
    end
  end
end
