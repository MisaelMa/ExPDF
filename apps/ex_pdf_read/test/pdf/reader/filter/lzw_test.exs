defmodule Pdf.Reader.Filter.LZWTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Filter.LZW

  # LZW encoding for tests:
  # We'll build known LZW-encoded sequences manually.
  #
  # PDF LZW: 9-to-12 bit variable-width codes.
  # Clear code = 256, EOD code = 257.
  # Initial code width = 9 bits.
  # EarlyChange 1 (default): code width increases BEFORE the table fills up
  #   (i.e., when entry count reaches 2^width - 1, switch to width+1).
  # EarlyChange 0: switch AFTER the entry count reaches 2^width.
  #
  # For simplicity, our tests encode very short sequences that stay at 9-bit codes.

  # Build a bit stream for a sequence of 9-bit codes.
  defp bits9(codes) do
    bits =
      Enum.reduce(codes, <<>>, fn code, acc ->
        # append 9 bits
        <<acc::bitstring, code::9>>
      end)

    # Pad to byte boundary
    pad = rem(8 - rem(bit_size(bits), 8), 8)
    <<bits::bitstring, 0::size(pad)>>
  end

  describe "decode/2 with EarlyChange 1 (default, task 2.5.1)" do
    test "decodes a simple sequence: Clear, 'A', 'B', EOD" do
      # Codes (9-bit): 256=Clear, 65='A', 66='B', 257=EOD
      encoded = bits9([256, 65, 66, 257])
      assert {:ok, "AB"} = LZW.decode(encoded, %{"EarlyChange" => 1})
    end

    test "default EarlyChange is 1" do
      encoded = bits9([256, 65, 66, 257])
      assert {:ok, "AB"} = LZW.decode(encoded, %{})
    end

    test "decodes repeated sequence using table entry" do
      # Codes: Clear, 65='A', 65='A', 65='A', EOD
      # After Clear: table has 0..255 + clear(256) + eod(257).
      # Code 65 → 'A'; table[258] = "AA" (prev=A + first_of_A = A)
      # Code 65 → 'A'; table[259] = "AA"  (prev=A + first_of_A = A)
      # Result: "AAA"
      encoded = bits9([256, 65, 65, 65, 257])
      assert {:ok, "AAA"} = LZW.decode(encoded, %{"EarlyChange" => 1})
    end
  end

  describe "decode/2 with EarlyChange 0 (task 2.5.3)" do
    test "decodes same simple sequence with EarlyChange 0" do
      # Same short sequence stays at 9-bit codes since table is tiny
      encoded = bits9([256, 65, 66, 257])
      assert {:ok, "AB"} = LZW.decode(encoded, %{"EarlyChange" => 0})
    end
  end
end
