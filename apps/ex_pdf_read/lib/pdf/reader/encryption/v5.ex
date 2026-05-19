defmodule Pdf.Reader.Encryption.V5 do
  @moduledoc """
  Implements PDF Standard Security Handler algorithms for V5/R6 (AES-256,
  PDF 2.0).  R=5 (deprecated Acrobat X beta variant) is explicitly rejected.

  ## Algorithms implemented

  | Algorithm   | Description                                                 | Function                |
  |-------------|-------------------------------------------------------------|-------------------------|
  | Alg 2.B     | PDF 2.0 iterative SHA mixing (`calculatePDF20Hash`)         | `pdf20_hash/3` (private)|
  | Alg 8       | User password authentication via Validation Salt            | `authenticate_user/2`   |
  | Alg 9       | Owner password authentication via Validation Salt + /U      | `authenticate_owner/2`  |
  | Alg 10      | File encryption key recovery via Key Salt + AES-256 of /UE | `authenticate_user/2`,  |
  |             | or /OE                                                      | `authenticate_owner/2`  |
  | —           | AES-256-CBC stream/string decryption with PKCS7 unpadding   | `decrypt_stream/5`,     |
  |             |                                                             | `decrypt_string/4`      |

  ## Algorithm 2.B — PDF 2.0 iterative SHA mixing

  Implements ISO 32000-2 § 7.6.4.3.4 "Algorithm 2.B" (also called
  `calculatePDF20Hash` in Mozilla pdf.js).

  ```
  K = SHA-256(initial_data)
  round = 0
  repeat while round < 64 OR last byte of E > (round - 32):
    K1 = (password ++ K ++ user_bytes) × 64
    E  = AES-128-CBC-encrypt(K1, key=K[0..15], IV=K[16..31], no padding)
    sum = sum of first 16 bytes of E (mod 3)
    K  = SHA-256(E) if sum==0
         SHA-384(E) if sum==1
         SHA-512(E) if sum==2
    round += 1
  return K[0..31]
  ```

  Where:
  - `initial_data` = password ++ salt (++ user_bytes for owner path)
  - `user_bytes` = empty binary for user path, U[0..47] for owner path

  ## Algorithm 8 — User Password Authentication (V5/R6)

  1. Truncate password to 127 bytes (UTF-8 encoded).
  2. hash = `pdf20_hash(password, password ++ U[32..39], <<>>)`
  3. If hash == U[0..31] → authentication passes.
  4. Compute `ue_key = pdf20_hash(password, password ++ U[40..47], <<>>)`
  5. AES-256-CBC-decrypt `/UE` with `ue_key` and IV = 16 zero bytes.
  6. Return `{:ok, file_key}` (32 bytes).

  ## Algorithm 9 — Owner Password Authentication (V5/R6)

  1. Truncate password to 127 bytes.
  2. U = handler.u (full 48 bytes).
  3. hash = `pdf20_hash(password, password ++ O[32..39] ++ U, U)`
  4. If hash == O[0..31] → authentication passes.
  5. Compute `oe_key = pdf20_hash(password, password ++ O[40..47] ++ U, U)`
  6. AES-256-CBC-decrypt `/OE` with `oe_key` and IV = 16 zero bytes.
  7. Return `{:ok, file_key}` (32 bytes).

  ## Algorithm 10 — File Key Recovery

  Embedded in `authenticate_user/2` and `authenticate_owner/2`.  After
  successful hash comparison, the appropriate key-derivation hash is computed
  and AES-256-CBC decryption (no padding, IV = 16 zero bytes) of `/UE` or
  `/OE` yields the 32-byte file encryption key.

  ## V5 decryption (streams and strings)

  For V5, the file encryption key is used DIRECTLY — no per-object key
  derivation step (unlike V1/V2/V4 which use `ObjectKey.derive/4`).  This is
  per PDF 2.0 § 7.6.5 (R-ENC26).

  Format: first 16 bytes of ciphertext = IV; remainder = AES-256-CBC ciphertext.
  After decryption, PKCS7 padding is stripped manually (last byte `N`, validate
  `1 ≤ N ≤ 16`, strip `N` bytes).  Invalid padding returns `:error` without
  raising.

  ## PKCS7 unpadding (shared helper)

  The same unpad logic is used by V4 (AES-128-CBC) and V5 (AES-256-CBC).
  Rather than depending on V4 (creating a cross-module coupling), V5 contains
  its own private implementation.  The design decision is documented here: if
  a shared `Pdf.Reader.Encryption.AES` helper module is introduced in a future
  phase, both V4 and V5 can be refactored to delegate to it without a breaking
  change.

  ## Spec references
  - PDF 2.0 (ISO 32000-2) § 7.6.4.3 — Algorithms 2.B, 8, 9, 10:
    https://www.pdfa.org/wp-content/uploads/2023/04/ISO_32000_2_2020_PDF_2.0_FDIS.pdf
  - NIST FIPS 197 — AES:
    https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
  - NIST SP 800-38A — CBC mode:
    https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf
  - Mozilla pdf.js src/core/crypto.js `calculatePDF20Hash` (Apache-2.0):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
  - Erlang OTP `:crypto` algorithm details:
    https://www.erlang.org/docs/27/apps/crypto/algorithm_details
  """

  alias Pdf.Reader.Encryption.StandardHandler

  # 16-byte zero IV used for /UE and /OE AES-256-CBC decryption (Algorithm 10)
  @zero_iv <<0::128>>

  # Maximum password length per PDF 2.0 § 7.6.4.3.2
  @max_password_bytes 127

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Authenticates a user password for V5/R6 using Algorithm 8.

  ## Parameters

  - `password` — the plaintext user password (UTF-8 string; truncated to 127 bytes).
  - `handler` — a `%StandardHandler{}` with `:revision`, `:u`, and `:ue` populated.

  ## Returns

  - `{:ok, file_key}` — password authenticated; `file_key` is the 32-byte file
    encryption key recovered by decrypting `/UE`.
  - `:error` — authentication failed (wrong password).
  - `{:error, :encrypted_unsupported_handler}` — revision is not 6 (e.g. R=5
    deprecated, per R-ENC25 / S-ENC10).
  """
  @spec authenticate_user(binary(), StandardHandler.t()) ::
          {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
  def authenticate_user(password, %StandardHandler{} = handler) when is_binary(password) do
    with :ok <- check_revision(handler) do
      pw = truncate_password(password)

      # Algorithm 8: validation salt = U[32..39]
      u_validation_salt = binary_part(handler.u, 32, 8)

      hash = pdf20_hash(pw, pw <> u_validation_salt, <<>>)

      if hash == binary_part(handler.u, 0, 32) do
        recover_file_key_user(pw, handler)
      else
        :error
      end
    end
  end

  @doc """
  Authenticates an owner password for V5/R6 using Algorithm 9.

  ## Parameters

  - `password` — the plaintext owner password (UTF-8 string; truncated to 127 bytes).
  - `handler` — a `%StandardHandler{}` with `:revision`, `:u`, `:o`, and `:oe` populated.

  ## Returns

  - `{:ok, file_key}` — password authenticated; `file_key` is the 32-byte file
    encryption key recovered by decrypting `/OE`.
  - `:error` — authentication failed.
  - `{:error, :encrypted_unsupported_handler}` — revision is not 6.
  """
  @spec authenticate_owner(binary(), StandardHandler.t()) ::
          {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
  def authenticate_owner(password, %StandardHandler{} = handler) when is_binary(password) do
    with :ok <- check_revision(handler) do
      pw = truncate_password(password)
      # U[0..47] is the full u field (48 bytes) used as additional input
      u_full = handler.u

      # Algorithm 9: validation salt = O[32..39]
      o_validation_salt = binary_part(handler.o, 32, 8)

      hash = pdf20_hash(pw, pw <> o_validation_salt <> u_full, u_full)

      if hash == binary_part(handler.o, 0, 32) do
        recover_file_key_owner(pw, u_full, handler)
      else
        :error
      end
    end
  end

  @doc """
  Decrypts a stream ciphertext using the V5/R6 AES-256-CBC algorithm.

  The file encryption key is used directly (no per-object key derivation).
  The first 16 bytes of `bytes` are the AES IV; the remainder is ciphertext.

  ## Parameters

  - `bytes` — the raw ciphertext bytes (IV ++ ciphertext).
  - `stream_dict` — the stream's dictionary (used to detect `/Identity` Crypt
    Filter overrides per R-ENC15/R-ENC20).
  - `obj_num` — the PDF object number (unused in V5 — kept for API symmetry).
  - `gen_num` — the PDF generation number (unused in V5 — kept for API symmetry).
  - `handler` — a `%StandardHandler{}` with `:file_key` populated (32 bytes).

  ## Returns

  - `{:ok, plaintext}` — decryption and PKCS7 unpadding succeeded.
  - `:error` — invalid PKCS7 padding (R-ENC14), or ciphertext too short.
  """
  @spec decrypt_stream(binary(), map(), non_neg_integer(), non_neg_integer(), StandardHandler.t()) ::
          {:ok, binary()} | :error
  def decrypt_stream(bytes, stream_dict, _obj_num, _gen_num, handler)
      when is_binary(bytes) do
    if identity_filter?(stream_dict) do
      {:ok, bytes}
    else
      aes256_decrypt(bytes, handler.file_key)
    end
  end

  @doc """
  Decrypts a string ciphertext using the V5/R6 AES-256-CBC algorithm.

  The file encryption key is used directly (no per-object key derivation).
  The first 16 bytes of `bytes` are the AES IV; the remainder is ciphertext.

  ## Parameters

  - `bytes` — the raw ciphertext bytes (IV ++ ciphertext).
  - `obj_num` — the PDF object number (unused in V5 — kept for API symmetry).
  - `gen_num` — the PDF generation number (unused in V5 — kept for API symmetry).
  - `handler` — a `%StandardHandler{}` with `:file_key` populated (32 bytes).

  ## Returns

  - `{:ok, plaintext}` — decryption and PKCS7 unpadding succeeded.
  - `:error` — invalid PKCS7 padding or ciphertext too short.
  """
  @spec decrypt_string(binary(), non_neg_integer(), non_neg_integer(), StandardHandler.t()) ::
          {:ok, binary()} | :error
  def decrypt_string(bytes, _obj_num, _gen_num, handler) when is_binary(bytes) do
    aes256_decrypt(bytes, handler.file_key)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # R-ENC25: reject R=5 (deprecated pre-standard variant)
  defp check_revision(%StandardHandler{revision: 6}), do: :ok
  defp check_revision(_), do: {:error, :encrypted_unsupported_handler}

  # Truncate password to 127 bytes per PDF 2.0 § 7.6.4.3.2
  defp truncate_password(password) when byte_size(password) > @max_password_bytes do
    binary_part(password, 0, @max_password_bytes)
  end

  defp truncate_password(password), do: password

  # ---------------------------------------------------------------------------
  # Algorithm 2.B — pdf20_hash/3 (calculatePDF20Hash)
  #
  # Parameters:
  #   password     — the (truncated) password bytes; used in K1 loop
  #   initial_data — password ++ salt [++ user_bytes]; used for initial SHA-256
  #   user_bytes   — U[0..47] for owner path, <<>> for user path; used in K1 loop
  #
  # Note: initial_data already contains password as prefix (that is how pdf.js
  # calls it). We compute SHA-256(initial_data) for K, then build K1 with
  # password ++ K ++ user_bytes.
  #
  # Source: ISO 32000-2 § 7.6.4.3.4 and Mozilla pdf.js PDF20._hash()
  # (Apache-2.0, https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js)
  # ---------------------------------------------------------------------------
  defp pdf20_hash(password, initial_data, user_bytes) do
    k = :crypto.hash(:sha256, initial_data)
    do_pdf20_loop(password, user_bytes, k, 0, 0)
  end

  # Loop condition: run at least 64 rounds; continue while last E byte > round - 32
  defp do_pdf20_loop(password, user_bytes, k, round, last_e_byte)
       when round < 64 or last_e_byte > round - 32 do
    # Build K1 = (password ++ K ++ user_bytes) × 64
    unit = password <> k <> user_bytes
    k1 = :binary.copy(unit, 64)

    # AES-128-CBC encrypt K1 with key=K[0..15], IV=K[16..31], no padding
    aes_key = binary_part(k, 0, 16)
    aes_iv = binary_part(k, 16, 16)

    e =
      :crypto.crypto_one_time(
        :aes_128_cbc,
        aes_key,
        aes_iv,
        k1,
        [{:padding, :none}, {:encrypt, true}]
      )

    # Sum of first 16 bytes of E mod 3 → selects next hash algorithm
    e_sum = for <<b <- binary_part(e, 0, 16)>>, reduce: 0, do: (acc -> acc + b)
    remainder = rem(e_sum, 3)

    new_k =
      case remainder do
        0 -> :crypto.hash(:sha256, e)
        1 -> :crypto.hash(:sha384, e)
        _ -> :crypto.hash(:sha512, e)
      end

    # last byte of E drives the while-condition
    new_last_e_byte = :binary.last(e)

    do_pdf20_loop(password, user_bytes, new_k, round + 1, new_last_e_byte)
  end

  # Loop complete: return first 32 bytes of K
  defp do_pdf20_loop(_password, _user_bytes, k, _round, _last_e_byte) do
    binary_part(k, 0, 32)
  end

  # Algorithm 10 — user path: derive key from U_key_salt and decrypt /UE
  defp recover_file_key_user(pw, handler) do
    u_key_salt = binary_part(handler.u, 40, 8)
    ue_key = pdf20_hash(pw, pw <> u_key_salt, <<>>)

    file_key =
      :crypto.crypto_one_time(
        :aes_256_cbc,
        ue_key,
        @zero_iv,
        handler.ue,
        [{:padding, :none}, {:encrypt, false}]
      )

    {:ok, file_key}
  end

  # Algorithm 10 — owner path: derive key from O_key_salt + U[0..47] and decrypt /OE
  defp recover_file_key_owner(pw, u_full, handler) do
    o_key_salt = binary_part(handler.o, 40, 8)
    oe_key = pdf20_hash(pw, pw <> o_key_salt <> u_full, u_full)

    file_key =
      :crypto.crypto_one_time(
        :aes_256_cbc,
        oe_key,
        @zero_iv,
        handler.oe,
        [{:padding, :none}, {:encrypt, false}]
      )

    {:ok, file_key}
  end

  # AES-256-CBC decryption: first 16 bytes = IV, rest = ciphertext
  # Returns {:ok, plaintext} or :error (short input or bad PKCS7 padding)
  defp aes256_decrypt(bytes, _file_key) when byte_size(bytes) < 32, do: :error

  defp aes256_decrypt(bytes, file_key) do
    iv = binary_part(bytes, 0, 16)
    ciphertext = binary_part(bytes, 16, byte_size(bytes) - 16)

    decrypted =
      :crypto.crypto_one_time(
        :aes_256_cbc,
        file_key,
        iv,
        ciphertext,
        [{:padding, :none}, {:encrypt, false}]
      )

    pkcs7_unpad(decrypted)
  end

  # PKCS7 unpadding — validates last byte N ∈ 1..16 and strips it (R-ENC14)
  defp pkcs7_unpad(data) when byte_size(data) == 0, do: :error

  defp pkcs7_unpad(data) do
    n = :binary.last(data)

    if n >= 1 and n <= 16 and n <= byte_size(data) do
      {:ok, binary_part(data, 0, byte_size(data) - n)}
    else
      :error
    end
  end

  # Detect /Identity Crypt Filter in stream dict (R-ENC15, R-ENC20)
  # Returns true when the effective crypt filter for this stream is :identity
  defp identity_filter?(stream_dict) when is_map(stream_dict) do
    case Map.get(stream_dict, "DecodeParms") do
      %{"Name" => {:name, "Identity"}} -> true
      _ -> false
    end
  end
end
