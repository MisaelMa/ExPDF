defmodule Pdf.Reader.XRef.ClassicTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.XRef.Classic

  # ---------------------------------------------------------------------------
  # 4.2.1 — parse/2 parses classic xref table
  # ---------------------------------------------------------------------------

  describe "parse/2" do
    test "parses single subsection with free and in-use entries" do
      # PDF spec § 7.5.4: each entry is 20 bytes:
      # 10-digit offset | space | 5-digit gen | space | n|f | EOL (2 bytes)
      bin = """
      xref
      0 3
      0000000000 65535 f\r
      0000000009 00000 n\r
      0000000058 00002 n\r
      trailer
      <</Size 3/Root 1 0 R>>
      startxref
      0
      %%EOF
      """

      assert {:ok, entries} = Classic.parse(bin, 0)
      assert Map.get(entries, {0, 65_535}) == :free
      assert Map.get(entries, {1, 0}) == {:in_use, 9, 0}
      assert Map.get(entries, {2, 2}) == {:in_use, 58, 2}
    end

    test "parses multiple subsections" do
      bin = """
      xref
      0 2
      0000000000 65535 f\r
      0000000009 00000 n\r
      5 2
      0000000100 00000 n\r
      0000000200 00000 n\r
      trailer
      <</Size 7/Root 1 0 R>>
      startxref
      0
      %%EOF
      """

      assert {:ok, entries} = Classic.parse(bin, 0)
      assert entries[{1, 0}] == {:in_use, 9, 0}
      assert entries[{5, 0}] == {:in_use, 100, 0}
      assert entries[{6, 0}] == {:in_use, 200, 0}
    end

    test "tolerates space+CR EOL variant ( n\\r instead of \\r\\n)" do
      # Some generators use " n " + CR or " f " + CR (20 bytes total)
      entry = "0000000042 00000 n \r"
      bin = "xref\n0 1\n#{entry}trailer\n<</Size 1/Root 1 0 R>>\nstartxref\n0\n%%EOF\n"
      assert {:ok, entries} = Classic.parse(bin, 0)
      assert entries[{0, 0}] == {:in_use, 42, 0}
    end

    test "returns error for invalid binary" do
      assert {:error, _} = Classic.parse(<<"not an xref">>, 0)
    end

    test "offset beyond binary length returns error" do
      assert {:error, _} = Classic.parse(<<"xref\n">>, 99_999)
    end
  end
end
