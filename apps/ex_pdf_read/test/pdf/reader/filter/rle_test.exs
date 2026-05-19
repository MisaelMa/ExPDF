defmodule Pdf.Reader.Filter.RLETest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Filter.RLE

  describe "decode/2" do
    test "decodes a literal run (task 2.4.1)" do
      # Length byte 0x02 = literal run of 3 bytes (0..127 means copy next n+1 bytes)
      # followed by EOD (128)
      input = <<0x02, ?A, ?B, ?C, 128>>
      assert {:ok, "ABC"} = RLE.decode(input, %{})
    end

    test "decodes a repeat run" do
      # Length byte 0xFE = repeat: 256 - 0xFE = 2, so repeat next byte 3 times
      input = <<0xFE, ?X, 128>>
      assert {:ok, "XXX"} = RLE.decode(input, %{})
    end

    test "EOD byte (128) terminates decoding" do
      # Immediately EOD → empty output
      assert {:ok, ""} = RLE.decode(<<128>>, %{})
    end

    test "handles multiple runs before EOD" do
      # Literal run: 0x00 = 1 byte literal → 'H'
      # Repeat run: 0xFE = repeat 3 times → 'i' 'i' 'i'
      # EOD: 128
      input = <<0x00, ?H, 0xFE, ?i, 128>>
      assert {:ok, "Hiii"} = RLE.decode(input, %{})
    end
  end
end
