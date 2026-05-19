defmodule Pdf.Reader.Encryption.ObjectKey do
  @moduledoc """
  Derives the per-object encryption key used for V1, V2, and V4 Standard
  Security Handler streams and strings.

  Implements Algorithm 1 from PDF 1.7 § 7.6.2, which produces an object-
  specific key from the file encryption key, the object number, the generation
  number, and the cipher family.

  ## Algorithm 1 (PDF 1.7 § 7.6.2)

  1. Start with the file encryption key bytes.
  2. Append `obj_num` as 3 little-endian bytes (low-order first).
  3. Append `gen_num` as 2 little-endian bytes (low-order first).
  4. If the cipher is AES, append the 4-byte literal `"sAlT"` (0x73 0x41 0x6c 0x54).
  5. Compute MD5 over the resulting byte sequence.
  6. Truncate to `min(byte_size(file_key) + 5, 16)` bytes.

  This function is NOT used for V5 (AES-256); V5 uses the file key directly
  without per-object derivation.

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.2 — General Encryption Algorithm:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - RFC 1321 (MD5):
    https://www.rfc-editor.org/rfc/rfc1321.html
  - Mozilla pdf.js src/core/crypto.js #buildObjectKey (Apache-2.0 cross-check):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
  """

  # "sAlT" — appended before MD5 when the effective cipher is AES (V4 AES-128)
  @salt <<0x73, 0x41, 0x6C, 0x54>>

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Derives a per-object encryption key.

  ## Parameters

  - `file_key` — the file encryption key derived by Algorithm 2 (V1/V2/V4).
    Typically 5 bytes (V1 RC4-40) or up to 16 bytes (V2/V4 RC4-128 / AES-128).
  - `obj_num` — the PDF object number (non-negative integer).
  - `gen_num` — the PDF generation number (non-negative integer; usually 0 for
    most in-use objects).
  - `cipher` — the effective cipher for this object.  Pass `:aes_128` for AES;
    any other value (including `:rc4`) is treated as RC4 (no "sAlT" suffix).

  ## Returns

  A binary of `min(byte_size(file_key) + 5, 16)` bytes.
  """
  @spec derive(binary(), non_neg_integer(), non_neg_integer(), :aes_128 | :rc4) :: binary()
  def derive(file_key, obj_num, gen_num, cipher) when is_binary(file_key) do
    input =
      file_key <>
        <<obj_num::little-24>> <>
        <<gen_num::little-16>> <>
        salt_suffix(cipher)

    hash = :crypto.hash(:md5, input)
    truncate_to = min(byte_size(file_key) + 5, 16)
    binary_part(hash, 0, truncate_to)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp salt_suffix(:aes_128), do: @salt
  defp salt_suffix(_), do: <<>>
end
