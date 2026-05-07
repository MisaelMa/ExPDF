defmodule Pdf.Reader.Encryption.ObjectKeyTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Encryption.ObjectKey

  # ---------------------------------------------------------------------------
  # PDF 1.7 (ISO 32000-1) § 7.6.2 — Per-object key derivation (Algorithm 1):
  #
  #   1. Append the low-order 3 bytes of the object number to the file key,
  #      low-order byte first.
  #   2. Append the low-order 2 bytes of the generation number, low-order byte
  #      first.
  #   3. If the encryption algorithm being used is AES (RC4 = no additional step;
  #      AES = append the 4-byte literal "sAlT" — bytes 73 41 6c 54).
  #   4. Compute the MD5 hash of the resulting byte sequence.
  #   5. Truncate to min(byte_size(file_key) + 5, 16) bytes.
  #
  # Cross-checked against Mozilla pdf.js src/core/crypto.js #buildObjectKey
  # (Apache-2.0):
  #   key[i++] = num & 0xff;
  #   key[i++] = (num >> 8) & 0xff;
  #   key[i++] = (num >> 16) & 0xff;
  #   key[i++] = gen & 0xff;
  #   key[i++] = (gen >> 8) & 0xff;
  #   if (isAes) { key[i++]=0x73; key[i++]=0x41; key[i++]=0x6c; key[i++]=0x54; }
  #   const hash = calculateMD5(key, 0, i);
  #   return hash.subarray(0, Math.min(n + 5, 16));
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Test case 1 — S-ENC15: AES cipher, 16-byte file key, obj=10, gen=0
  #
  # Algorithm trace (manually verified):
  #   file_key = <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>  (<<1::8*16>>)
  #   obj bytes = <<10, 0, 0>>  (little-endian 3 bytes of 10)
  #   gen bytes = <<0, 0>>      (little-endian 2 bytes of 0)
  #   sAlT      = <<0x73, 0x41, 0x6c, 0x54>>
  #   input     = file_key ++ obj_bytes ++ gen_bytes ++ sAlT
  #             = 00000000000000000000000000000001 0A0000 0000 73416C54
  #   MD5(input) = 53A3E290D5F8F9E9D152700CFA8CAB0F  (verified via :crypto.hash(:md5, input))
  #   truncate_to = min(16 + 5, 16) = 16
  #   result    = 53A3E290D5F8F9E9D152700CFA8CAB0F  (all 16 MD5 bytes)
  # ---------------------------------------------------------------------------
  describe "derive/4 — AES, 16-byte file key" do
    test "S-ENC15: obj=10, gen=0, :aes_128 → correct 16-byte key" do
      file_key = <<1::8*16>>
      expected = Base.decode16!("53A3E290D5F8F9E9D152700CFA8CAB0F")

      result = ObjectKey.derive(file_key, 10, 0, :aes_128)

      assert byte_size(result) == 16
      assert Base.encode16(result) == Base.encode16(expected)
    end

    test "appends sAlT bytes (0x73, 0x41, 0x6c, 0x54) for AES cipher" do
      # Distinguish AES from RC4 by comparing the two results with identical params.
      # They MUST differ because AES input includes 4 extra bytes.
      file_key =
        <<0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB,
          0xCD, 0xEF>>

      aes_key = ObjectKey.derive(file_key, 1, 0, :aes_128)
      rc4_key = ObjectKey.derive(file_key, 1, 0, :rc4)

      refute aes_key == rc4_key
    end
  end

  # ---------------------------------------------------------------------------
  # Test case 2 — RC4, 16-byte file key, obj=1, gen=0
  #
  # Algorithm trace:
  #   file_key = <<0xFF>> * 16
  #   obj bytes = <<1, 0, 0>>
  #   gen bytes = <<0, 0>>
  #   (no sAlT for RC4)
  #   input     = FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF 010000 0000
  #   MD5(input) = 1087948AC8251562A809D19943902135  (verified via :crypto)
  #   truncate_to = min(16 + 5, 16) = 16
  #   result    = 1087948AC8251562A809D19943902135
  # ---------------------------------------------------------------------------
  describe "derive/4 — RC4, 16-byte file key" do
    test "obj=1, gen=0 → correct 16-byte key, no sAlT suffix" do
      file_key = :binary.copy(<<0xFF>>, 16)
      expected = Base.decode16!("1087948AC8251562A809D19943902135")

      result = ObjectKey.derive(file_key, 1, 0, :rc4)

      assert byte_size(result) == 16
      assert Base.encode16(result) == Base.encode16(expected)
    end
  end

  # ---------------------------------------------------------------------------
  # Test case 3 — V1-style: 5-byte file key (RC4-40), obj=5, gen=0
  #
  # Algorithm trace:
  #   file_key = <<0x01, 0x02, 0x03, 0x04, 0x05>>  (5 bytes)
  #   obj bytes = <<5, 0, 0>>
  #   gen bytes = <<0, 0>>
  #   (no sAlT for RC4)
  #   input     = 0102030405 050000 0000  (10 bytes total)
  #   MD5(input) = 6349C8D6A6B5393B48C5BCA56AAD6A4A  (full 16-byte MD5)
  #   truncate_to = min(5 + 5, 16) = 10
  #   result    = 6349C8D6A6B5393B48C5  (first 10 bytes)
  #
  # Verifies: shorter file key produces correspondingly truncated per-object key
  # ---------------------------------------------------------------------------
  describe "derive/4 — V1 RC4-40, 5-byte file key" do
    test "obj=5, gen=0 → truncated to 10 bytes" do
      file_key = <<0x01, 0x02, 0x03, 0x04, 0x05>>
      expected = Base.decode16!("6349C8D6A6B5393B48C5")

      result = ObjectKey.derive(file_key, 5, 0, :rc4)

      assert byte_size(result) == 10
      assert Base.encode16(result) == Base.encode16(expected)
    end

    test "truncation formula is min(file_key_length + 5, 16)" do
      # 5-byte key → min(10, 16) = 10
      file_key5 = :binary.copy(<<0x01>>, 5)
      assert byte_size(ObjectKey.derive(file_key5, 1, 0, :rc4)) == 10

      # 11-byte key → min(16, 16) = 16
      file_key11 = :binary.copy(<<0x01>>, 11)
      assert byte_size(ObjectKey.derive(file_key11, 1, 0, :rc4)) == 16

      # 16-byte key → min(21, 16) = 16 (capped)
      file_key16 = :binary.copy(<<0x01>>, 16)
      assert byte_size(ObjectKey.derive(file_key16, 1, 0, :rc4)) == 16
    end
  end

  # ---------------------------------------------------------------------------
  # Additional structural checks
  # ---------------------------------------------------------------------------
  describe "derive/4 — object number encoding" do
    test "different obj_num values produce different keys (same file_key and gen)" do
      file_key = :binary.copy(<<0xAA>>, 16)

      key1 = ObjectKey.derive(file_key, 1, 0, :rc4)
      key2 = ObjectKey.derive(file_key, 2, 0, :rc4)

      refute key1 == key2
    end

    test "different gen_num values produce different keys (same file_key and obj)" do
      file_key = :binary.copy(<<0xAA>>, 16)

      key0 = ObjectKey.derive(file_key, 5, 0, :rc4)
      key1 = ObjectKey.derive(file_key, 5, 1, :rc4)

      refute key0 == key1
    end
  end
end
