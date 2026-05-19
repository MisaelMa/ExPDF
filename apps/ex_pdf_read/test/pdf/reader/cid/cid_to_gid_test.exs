defmodule Pdf.Reader.CID.CIDToGIDMapTest do
  use ExUnit.Case, async: true

  # Spec references:
  # - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts
  # - PDF 1.7 § 9.7.4 — CIDFonts (/CIDToGIDMap key)
  # https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

  alias Pdf.Reader.CID.CIDToGIDMap
  alias Pdf.Reader.Document

  defp empty_doc do
    %Document{binary: <<>>, xref: %{}, cache: %{}, trailer: %{}}
  end

  describe "parse/2 — S-CID7, R-CID10" do
    test "parse({:name, 'Identity'}, doc) returns {:ok, :identity, doc}" do
      doc = empty_doc()
      assert {:ok, :identity, ^doc} = CIDToGIDMap.parse({:name, "Identity"}, doc)
    end

    test "parse({:stream, dict, raw_bytes}, doc) with unfiltered bytes returns stream_map" do
      # A 4-byte map: CID 0 → GID 5, CID 1 → GID 10
      raw = <<0, 5, 0, 10>>
      doc = empty_doc()
      assert {:ok, {:stream_map, ^raw}, ^doc} = CIDToGIDMap.parse({:stream, %{}, raw}, doc)
    end

    test "parse with unknown value returns {:error, :malformed}" do
      doc = empty_doc()
      assert {:error, :malformed} = CIDToGIDMap.parse({:name, "SomeOtherName"}, doc)
    end
  end

  describe "lookup/2 — S-CID7, S-CID8, R-CID11" do
    test "lookup(:identity, 5) returns {:ok, 5} — identity maps CID == GID" do
      assert CIDToGIDMap.lookup(:identity, 5) == {:ok, 5}
    end

    test "lookup(:identity, 42) returns {:ok, 42}" do
      assert CIDToGIDMap.lookup(:identity, 42) == {:ok, 42}
    end

    test "lookup({:stream_map, bytes}, 0) returns {:ok, 5} from first uint16-BE pair" do
      # bytes: <<0, 5, 0, 10>> → CID 0 → GID 5, CID 1 → GID 10
      bytes = <<0, 5, 0, 10>>
      assert CIDToGIDMap.lookup({:stream_map, bytes}, 0) == {:ok, 5}
    end

    test "lookup({:stream_map, bytes}, 1) returns {:ok, 10} from second uint16-BE pair" do
      bytes = <<0, 5, 0, 10>>
      assert CIDToGIDMap.lookup({:stream_map, bytes}, 1) == {:ok, 10}
    end

    test "lookup({:stream_map, bytes}, CID out of range) returns :error" do
      bytes = <<0, 5, 0, 10>>
      assert CIDToGIDMap.lookup({:stream_map, bytes}, 99) == :error
    end
  end
end
