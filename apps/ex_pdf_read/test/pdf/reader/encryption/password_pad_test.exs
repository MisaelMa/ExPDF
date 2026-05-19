defmodule Pdf.Reader.Encryption.PasswordPadTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption.PasswordPad

  # ---------------------------------------------------------------------------
  # PDF 1.7 (ISO 32000-1) § 7.6.3.3 — Algorithm 2, step (a):
  #
  #   "Pad or truncate the password string to exactly 32 bytes.  If the password
  #   string is more than 32 bytes long, use only its first 32 bytes; if it is
  #   less than 32 bytes long, pad it by appending the required number of
  #   additional bytes from the beginning of the following padding string:
  #
  #     < 28 BF 4E 5E 4E 75 8A 41 64 00 4E 56 FF FA 01 08
  #       2E 2E 00 B6 D0 68 3E 80 2F 0C A9 FE 64 53 69 7A >
  #
  #   That is, if the password string is n bytes long, append the first 32 - n
  #   bytes of the padding string to the end of the password string."
  #
  # Cross-checked against:
  #   Mozilla pdf.js src/core/crypto.js — CipherTransformFactory._defaultPasswordBytes
  #   Uint8Array: [0x28,0xbf,0x4e,0x5e,0x4e,0x75,0x8a,0x41,0x64,0x00,0x4e,0x56,
  #                0xff,0xfa,0x01,0x08,0x2e,0x2e,0x00,0xb6,0xd0,0x68,0x3e,0x80,
  #                0x2f,0x0c,0xa9,0xfe,0x64,0x53,0x69,0x7a]
  # ---------------------------------------------------------------------------

  @expected_constant <<
    0x28,
    0xBF,
    0x4E,
    0x5E,
    0x4E,
    0x75,
    0x8A,
    0x41,
    0x64,
    0x00,
    0x4E,
    0x56,
    0xFF,
    0xFA,
    0x01,
    0x08,
    0x2E,
    0x2E,
    0x00,
    0xB6,
    0xD0,
    0x68,
    0x3E,
    0x80,
    0x2F,
    0x0C,
    0xA9,
    0xFE,
    0x64,
    0x53,
    0x69,
    0x7A
  >>

  describe "constant/0" do
    test "returns the canonical 32-byte PDF password-padding constant" do
      pad = PasswordPad.constant()

      # Must be exactly 32 bytes
      assert byte_size(pad) == 32

      # Must match the spec value verbatim (encode both sides for clear diff output)
      assert Base.encode16(pad) == Base.encode16(@expected_constant)
    end

    test "first byte is 0x28" do
      <<first, _rest::binary>> = PasswordPad.constant()
      assert first == 0x28
    end

    test "last byte is 0x7A" do
      pad = PasswordPad.constant()
      <<last>> = binary_part(pad, 31, 1)
      assert last == 0x7A
    end
  end

  describe "pad/1" do
    test "empty string is padded to the full 32-byte constant" do
      result = PasswordPad.pad("")

      assert byte_size(result) == 32
      assert result == @expected_constant
    end

    test "short password is padded to 32 bytes beginning with the password bytes" do
      result = PasswordPad.pad("test")

      assert byte_size(result) == 32
      assert binary_part(result, 0, 4) == "test"
      # Remaining 28 bytes must be the first 28 bytes of the padding constant
      <<_pw::binary-size(4), tail::binary>> = result
      assert tail == binary_part(@expected_constant, 0, 28)
    end

    test "32-byte password is returned unchanged" do
      password = String.duplicate("A", 32)
      result = PasswordPad.pad(password)

      assert byte_size(result) == 32
      assert result == password
    end

    test "password longer than 32 bytes is truncated to 32 bytes" do
      password = String.duplicate("B", 40)
      result = PasswordPad.pad(password)

      assert byte_size(result) == 32
      assert result == binary_part(password, 0, 32)
    end
  end
end
