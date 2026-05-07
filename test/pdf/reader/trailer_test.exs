defmodule Pdf.Reader.TrailerTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Trailer

  # ---------------------------------------------------------------------------
  # 4.1.1 — locate_startxref/1
  # ---------------------------------------------------------------------------

  describe "locate_startxref/1" do
    test "finds startxref offset from a canonical binary" do
      bin = """
      %PDF-1.4
      1 0 obj
      42
      endobj
      xref
      0 2
      0000000000 65535 f\r
      0000000009 00000 n\r
      trailer
      <</Size 2/Root 1 0 R>>
      startxref
      18
      %%EOF
      """

      assert {:ok, 18} = Trailer.locate_startxref(bin)
    end

    test "tolerates trailing whitespace after %%EOF" do
      bin = "startxref\n42\n%%EOF\n\n"
      assert {:ok, 42} = Trailer.locate_startxref(bin)
    end

    test "tolerates CRLF line endings" do
      bin = "startxref\r\n100\r\n%%EOF\r\n"
      assert {:ok, 100} = Trailer.locate_startxref(bin)
    end

    test "multiple %%EOF markers — uses the last one" do
      bin = "%%EOF\nstartxref\n55\n%%EOF\n"
      assert {:ok, 55} = Trailer.locate_startxref(bin)
    end

    test "missing %%EOF returns error" do
      bin = "startxref\n42\n"
      assert {:error, :malformed} = Trailer.locate_startxref(bin)
    end

    test "missing startxref returns error" do
      bin = "some garbage\n%%EOF\n"
      assert {:error, :malformed} = Trailer.locate_startxref(bin)
    end

    test "non-integer startxref offset returns error" do
      bin = "startxref\nnot_a_number\n%%EOF\n"
      assert {:error, :malformed} = Trailer.locate_startxref(bin)
    end
  end

  # ---------------------------------------------------------------------------
  # 4.1.3 — parse/2 parses the trailer dict at xref+trailer section offset
  # ---------------------------------------------------------------------------

  describe "parse/2" do
    test "parses a classic trailer dict" do
      # The binary has the trailer dict at offset 0 for simplicity
      # Normally offset is where the xref section begins, but parse/2
      # seeks forward to the `trailer` keyword from that offset.
      xref_section = """
      xref
      0 2
      0000000000 65535 f\r
      0000000009 00000 n\r
      trailer
      <</Size 2/Root 1 0 R/Info 2 0 R>>
      startxref
      0
      %%EOF
      """

      assert {:ok, trailer} = Trailer.parse(xref_section, 0)
      assert trailer.size == 2
      assert trailer.root == {:ref, 1, 0}
      assert trailer.info == {:ref, 2, 0}
      assert is_nil(trailer.encrypt)
      assert is_nil(trailer.prev)
    end

    test "parses /Prev chain pointer" do
      xref_section = """
      xref
      0 1
      0000000000 65535 f\r
      trailer
      <</Size 1/Root 1 0 R/Prev 100>>
      startxref
      200
      %%EOF
      """

      assert {:ok, trailer} = Trailer.parse(xref_section, 0)
      assert trailer.prev == 100
    end

    test "parses /Encrypt entry (non-nil signals encryption)" do
      xref_section = """
      xref
      0 1
      0000000000 65535 f\r
      trailer
      <</Size 1/Root 1 0 R/Encrypt 3 0 R>>
      startxref
      0
      %%EOF
      """

      assert {:ok, trailer} = Trailer.parse(xref_section, 0)
      assert trailer.encrypt == {:ref, 3, 0}
    end

    test "offset beyond binary length returns error" do
      assert {:error, :malformed} = Trailer.parse(<<"xref\n">>, 99_999)
    end
  end
end
