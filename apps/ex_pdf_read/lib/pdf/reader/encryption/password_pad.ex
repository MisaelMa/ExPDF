defmodule Pdf.Reader.Encryption.PasswordPad do
  @moduledoc """
  Provides the canonical 32-byte PDF password-padding constant and a helper
  to pad (or truncate) an arbitrary password binary to exactly 32 bytes.

  The padding constant is defined verbatim in the PDF specification and is
  used in Algorithm 2 (file encryption key derivation) as well as Algorithms
  3–5 (owner/user password authentication) for Standard Security Handler
  revisions R=2 through R=4.

  ## Usage

  ```elixir
  padded = PasswordPad.pad(user_supplied_password)
  # padded is always exactly 32 bytes
  ```

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.3.3 Algorithm 2 (step a — padding):
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - RFC 1321 (MD5 — used alongside this constant in Algorithm 2):
    https://www.rfc-editor.org/rfc/rfc1321.html
  - Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference implementation):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
    (CipherTransformFactory._defaultPasswordBytes — cross-check verified)
  """

  # ---------------------------------------------------------------------------
  # The 32-byte padding constant from PDF 1.7 § 7.6.3.3.
  #
  # Verified against Mozilla pdf.js CipherTransformFactory._defaultPasswordBytes:
  #   [0x28,0xbf,0x4e,0x5e,0x4e,0x75,0x8a,0x41,0x64,0x00,0x4e,0x56,
  #    0xff,0xfa,0x01,0x08,0x2e,0x2e,0x00,0xb6,0xd0,0x68,0x3e,0x80,
  #    0x2f,0x0c,0xa9,0xfe,0x64,0x53,0x69,0x7a]
  # ---------------------------------------------------------------------------
  @pad_constant <<
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

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns the canonical 32-byte PDF password-padding constant.

  Defined in PDF 1.7 § 7.6.3.3 as a fixed magic value used to pad short
  passwords before they are fed into MD5 hashing.
  """
  @spec constant() :: <<_::256>>
  def constant, do: @pad_constant

  @doc """
  Pads or truncates `password` to exactly 32 bytes per PDF 1.7 § 7.6.3.3.

  - If `password` is shorter than 32 bytes: appends bytes from `@pad_constant`
    until the result is 32 bytes long.
  - If `password` is exactly 32 bytes: returns it unchanged.
  - If `password` is longer than 32 bytes: truncates to the first 32 bytes.
  """
  @spec pad(binary()) :: <<_::256>>
  def pad(password) when is_binary(password) do
    n = byte_size(password)

    cond do
      n >= 32 ->
        binary_part(password, 0, 32)

      n == 0 ->
        @pad_constant

      true ->
        # Append the first (32 - n) bytes of the padding constant
        take = 32 - n
        password <> binary_part(@pad_constant, 0, take)
    end
  end
end
