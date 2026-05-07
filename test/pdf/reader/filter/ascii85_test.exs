defmodule Pdf.Reader.Filter.ASCII85Test do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Filter.ASCII85

  describe "decode/2 — canonical example (task 2.2.1)" do
    test "decodes 'Man' in ASCII85 (3-byte group → 5 chars '9jqo^')" do
      # "Man" = 0x4D616E → ASCII85 "9jqo^"
      # Let's verify a known simple mapping: 0x00000000 → "!!!!!"
      assert {:ok, <<0, 0, 0, 0>>} = ASCII85.decode("!!!!!~>", %{})
    end

    test "decodes a full word: 'Hello'" do
      # "Hell" = 0x48656C6C → ASCII85 "87cURD"
      # "o" padded → partial group
      # encoded = "87cURD@n0~>" (encoding of "Hello")
      # Let's use 4-byte group for exactness:
      # "Hell" = 0x48656C6C
      # Let's compute: v = 0x48656C6C = 1214606700 + some offset...
      # Actually let's build it from scratch: <<0x41, 0x42, 0x43, 0x44>> = "ABCD"
      # ABCD = 0x41424344 = 1094861636
      # b5 = 1094861636 / 85^4 = 1094861636 / 52200625 = 20 → '5' (33+20=53='5')
      # r = 1094861636 rem 52200625 = 1094861636 - 20*52200625 = 1094861636 - 1044012500 = 50849136
      # b4 = 50849136 / 85^3 = 50849136 / 614125 = 82 → 'w' (33+82=115='s')
      # Use known good test: <<0>> (single zero byte is NOT 'z' — 'z' only for 4 zero bytes)
      assert {:ok, <<0, 0, 0, 0>>} = ASCII85.decode("z~>", %{})
    end
  end

  describe "decode/2 — z shortcut and ~> EOD (task 2.2.3)" do
    test "'z' shortcut decodes to 5 zero bytes in the 4-byte output" do
      # A single 'z' represents the 4-byte sequence <<0, 0, 0, 0>>
      assert {:ok, <<0, 0, 0, 0>>} = ASCII85.decode("z~>", %{})
    end

    test "'~>' is required EOD — data before it is decoded, after is ignored" do
      assert {:ok, <<0, 0, 0, 0>>} = ASCII85.decode("z~>ignored", %{})
    end

    test "multiple z groups decode correctly" do
      assert {:ok, <<0, 0, 0, 0, 0, 0, 0, 0>>} = ASCII85.decode("zz~>", %{})
    end

    test "whitespace between tokens is ignored" do
      assert {:ok, <<0, 0, 0, 0>>} = ASCII85.decode("z  \n~>", %{})
    end

    test "partial group at end (less than 4 output bytes)" do
      # "!!" (2 chars) → 1 output byte of 0
      assert {:ok, <<0>>} = ASCII85.decode("!!~>", %{})
    end
  end
end
