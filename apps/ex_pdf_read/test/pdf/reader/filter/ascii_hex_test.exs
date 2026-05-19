defmodule Pdf.Reader.Filter.ASCIIHexTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Filter.ASCIIHex

  describe "decode/2" do
    test "decodes canonical hex sequence to binary (task 2.3.1)" do
      # "48 65 6C 6C 6F>" → "Hello"
      assert {:ok, "Hello"} = ASCIIHex.decode("48 65 6C 6C 6F>", %{})
    end

    test "whitespace-tolerant: tabs and newlines are ignored" do
      assert {:ok, "Hello"} = ASCIIHex.decode("48\t65\n6C\r6C6F>", %{})
    end

    test "'>' is EOD — trailing data after '>' is ignored" do
      assert {:ok, "Hi"} = ASCIIHex.decode("48 69> ignored", %{})
    end

    test "handles input without explicit '>' EOD marker" do
      assert {:ok, "Hi"} = ASCIIHex.decode("4869", %{})
    end

    test "odd number of hex digits pads last nibble with 0 (task 2.3.2)" do
      # "6" alone → "60" → <<0x60>> = "`"
      assert {:ok, <<0x60>>} = ASCIIHex.decode("6>", %{})
    end

    test "returns error for invalid hex character" do
      assert {:error, _} = ASCIIHex.decode("4G>", %{})
    end
  end
end
