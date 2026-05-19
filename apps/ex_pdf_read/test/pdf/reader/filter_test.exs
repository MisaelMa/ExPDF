defmodule Pdf.Reader.FilterTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Filter

  describe "apply_chain/3" do
    test "applies a single filter (identity via passthrough stub)" do
      # ASCIIHexDecode "48656C6C6F>" → "Hello"
      encoded = "48 65 6C 6C 6F>"
      assert {:ok, "Hello"} = Filter.apply_chain(encoded, ["ASCIIHexDecode"], [%{}])
    end

    test "unknown filter returns {:error, {:unsupported_filter, name}}" do
      assert {:error, {:unsupported_filter, :CCITTFaxDecode}} =
               Filter.apply_chain("data", ["CCITTFaxDecode"], [%{}])
    end

    test "empty filter list returns bytes unchanged" do
      assert {:ok, "raw bytes"} = Filter.apply_chain("raw bytes", [], [])
    end
  end

  describe "apply_chain/3 DecodeParms normalization (2.6)" do
    test "single-name filter + single-dict DecodeParms applies correctly" do
      encoded = "48 65 6C 6C 6F>"

      assert {:ok, "Hello"} =
               Filter.apply_chain(encoded, "ASCIIHexDecode", %{"Columns" => 5})
    end

    test ":null array entries become empty maps" do
      # A filter array with :null DecodeParms entry should treat it as %{}
      encoded = "48 65 6C 6C 6F>"

      assert {:ok, "Hello"} =
               Filter.apply_chain(encoded, ["ASCIIHexDecode"], [:null])
    end
  end
end
