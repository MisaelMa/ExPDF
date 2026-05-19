defmodule Pdf.Reader.Encryption.V1V2 do
  @moduledoc """
  Implements PDF Standard Security Handler algorithms for V1 (RC4-40) and
  V2 (RC4-128) — revisions R=2 and R=3/4.

  ## Algorithms implemented

  | Algorithm | Description                                              | Function             |
  |-----------|----------------------------------------------------------|----------------------|
  | Alg 2     | File encryption key derivation (MD5 + optional 50×)     | `derive_file_key/2`  |
  | Alg 4     | User password auth for R=2 (RC4 of pad constant)        | `authenticate_user/2`|
  | Alg 5     | User password auth for R≥3 (RC4 with 19-step iterations)| `authenticate_user/2`|
  | Alg 7     | Owner → user password derivation                        | `derive_user_from_owner/2` |

  All public functions perform an RC4 availability check first.  On systems
  where `:rc4` is not in `:crypto.supports(:ciphers)` (e.g. OpenSSL 3.x with
  FIPS mode), every function returns `{:error, :encrypted_unsupported_handler}`
  rather than crashing.

  ## Algorithm 2 — File Encryption Key (PDF 1.7 § 7.6.3.3, step a–h)

  1. Pad the user password to 32 bytes via `PasswordPad.pad/1`.
  2. MD5 streaming: hash(padded_pw ++ /O ++ <<P::little-32>> ++ /ID[0]).
  3. If R ≥ 4 and `encrypt_metadata == false`, append `<<0xFF,0xFF,0xFF,0xFF>>`.
  4. If R ≥ 3, iterate MD5 × 50 on the first `key_len` bytes of the digest.
  5. Truncate to first `key_len = Length / 8` bytes (min 5 for V1).

  ## Algorithm 4 — User Auth for R=2

  1. Derive file key via Algorithm 2.
  2. RC4-encrypt the 32-byte padding constant with the file key.
  3. Compare result byte-for-byte with /U (32 bytes).

  ## Algorithm 5 — User Auth for R≥3

  1. Derive file key via Algorithm 2.
  2. MD5(padding_constant ++ /ID[0]) → 16 bytes.
  3. RC4-encrypt those 16 bytes with the file key.
  4. For i in 1..19: XOR each byte of file_key with i → RC4-encrypt previous result.
  5. Compare final 16 bytes to the first 16 bytes of /U.

  ## Algorithm 7 — Owner → User Password

  1. Pad the owner password to 32 bytes.
  2. MD5 it; if R ≥ 3, iterate MD5 × 50 on the full 16 bytes.
  3. Truncate to `key_len` bytes → this becomes the RC4 key.
  4. For R=2: RC4-decrypt /O once.
  5. For R≥3: 20 iterative RC4 passes in reverse order (i=19 down to 0),
     XORing each key byte with i.
  6. The result is the padded user password.  Feed it to `authenticate_user/2`.

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.3.3 — Algorithms 2, 4, 5, 7:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - RFC 1321 (MD5):
    https://www.rfc-editor.org/rfc/rfc1321.html
  - Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference implementation):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
  - Erlang OTP `:crypto` algorithm details:
    https://www.erlang.org/docs/27/apps/crypto/algorithm_details
  """

  alias Pdf.Reader.Encryption.{ObjectKey, PasswordPad, StandardHandler}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Decrypts a stream ciphertext blob using the V1/V2 RC4 algorithm.

  Derives a per-object key from `handler.file_key`, `obj_num`, and `gen_num`
  using `ObjectKey.derive/4`, then applies RC4 decryption.

  ## Parameters

  - `bytes` — the raw stream bytes (RC4 ciphertext).
  - `_stream_dict` — the stream dictionary (unused for V1/V2; kept for API symmetry with V4/V5).
  - `obj_num` — the PDF object number.
  - `gen_num` — the PDF generation number.
  - `handler` — a `%StandardHandler{}` with `:file_key` populated.

  ## Returns

  - `{:ok, plaintext}` — successfully decrypted.
  - `{:error, :encrypted_unsupported_handler}` — RC4 not available at runtime.

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.2 — General Encryption Algorithm:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  """
  @spec decrypt_stream(binary(), map(), non_neg_integer(), non_neg_integer(), StandardHandler.t()) ::
          {:ok, binary()} | {:error, :encrypted_unsupported_handler}
  def decrypt_stream(bytes, _stream_dict, obj_num, gen_num, %StandardHandler{} = handler)
      when is_binary(bytes) do
    with :ok <- check_rc4() do
      key = ObjectKey.derive(handler.file_key, obj_num, gen_num, :rc4)
      {:ok, :crypto.crypto_one_time(:rc4, key, bytes, false)}
    end
  end

  @doc """
  Decrypts a string ciphertext using the V1/V2 RC4 algorithm.

  Derives a per-object key from `handler.file_key`, `obj_num`, and `gen_num`
  using `ObjectKey.derive/4`, then applies RC4 decryption.

  ## Parameters

  - `bytes` — the raw string bytes (RC4 ciphertext).
  - `obj_num` — the PDF object number.
  - `gen_num` — the PDF generation number.
  - `handler` — a `%StandardHandler{}` with `:file_key` populated.

  ## Returns

  - `{:ok, plaintext}` — successfully decrypted.
  - `{:error, :encrypted_unsupported_handler}` — RC4 not available at runtime.

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.2 — General Encryption Algorithm:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  """
  @spec decrypt_string(binary(), non_neg_integer(), non_neg_integer(), StandardHandler.t()) ::
          {:ok, binary()} | {:error, :encrypted_unsupported_handler}
  def decrypt_string(bytes, obj_num, gen_num, %StandardHandler{} = handler)
      when is_binary(bytes) do
    with :ok <- check_rc4() do
      key = ObjectKey.derive(handler.file_key, obj_num, gen_num, :rc4)
      {:ok, :crypto.crypto_one_time(:rc4, key, bytes, false)}
    end
  end

  @doc """
  Derives the file encryption key for V1/V2/V4 using Algorithm 2.

  ## Parameters

  - `password` — the plaintext user password (any length; padded/truncated internally).
  - `handler` — a `%StandardHandler{}` with `:revision`, `:length`, `:o`, `:p`,
    `:id`, and `:encrypt_metadata` populated.

  ## Returns

  A binary of `handler.length / 8` bytes (e.g. 5 bytes for V1/R=2, 16 bytes for
  V2/R=3 with Length=128).

  Does NOT check RC4 availability — the caller (`authenticate_user/2`) guards
  that.  Safe to call from tests or other modules that already checked.
  """
  @spec derive_file_key(binary(), StandardHandler.t()) :: binary()
  def derive_file_key(password, %StandardHandler{} = handler) when is_binary(password) do
    key_len = key_length(handler)

    padded_pw = PasswordPad.pad(password)
    p_le = <<handler.p::little-32>>

    # Streaming MD5: padded_pw ++ /O ++ P_le ++ /ID[0]
    hash =
      :crypto.hash_init(:md5)
      |> :crypto.hash_update(padded_pw)
      |> :crypto.hash_update(handler.o)
      |> :crypto.hash_update(p_le)
      |> :crypto.hash_update(handler.id)
      |> maybe_append_metadata_flag(handler)
      |> :crypto.hash_final()

    # R >= 3: iterate MD5 × 50 on first key_len bytes
    key = maybe_iterate(hash, handler.revision, key_len)

    binary_part(key, 0, key_len)
  end

  @doc """
  Authenticates a user password against the `/U` value in the handler.

  Uses Algorithm 4 for R=2 and Algorithm 5 for R≥3.

  ## Returns

  - `{:ok, file_key}` — password authenticated; `file_key` is the derived
    file encryption key (5 bytes for V1, up to 16 bytes for V2/V4).
  - `:error` — authentication failed (wrong password).
  - `{:error, :encrypted_unsupported_handler}` — RC4 not available on this
    runtime (per R-ENC29 / S-ENC14).
  """
  @spec authenticate_user(binary(), StandardHandler.t()) ::
          {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
  def authenticate_user(password, %StandardHandler{} = handler) when is_binary(password) do
    with :ok <- check_rc4() do
      file_key = derive_file_key(password, handler)

      if verify_user(file_key, handler) do
        {:ok, file_key}
      else
        :error
      end
    end
  end

  @doc """
  Derives the padded user password from the owner password using Algorithm 7,
  then authenticates via `authenticate_user/2`.

  ## Returns

  - `{:ok, file_key}` — owner password authenticated.
  - `:error` — owner password authentication failed.
  - `{:error, :encrypted_unsupported_handler}` — RC4 not available.
  """
  @spec authenticate_owner(binary(), StandardHandler.t()) ::
          {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
  def authenticate_owner(password, %StandardHandler{} = handler) when is_binary(password) do
    with :ok <- check_rc4(),
         {:ok, derived_padded_user} <- derive_user_from_owner(password, handler) do
      # Feed derived padded user password directly to authenticate_user.
      # PasswordPad.pad/1 truncates to first 32 bytes, so this is safe.
      authenticate_user(derived_padded_user, handler)
    end
  end

  @doc """
  Derives the padded user password from the owner password using Algorithm 7.

  ## Steps

  1. Pad owner password to 32 bytes.
  2. MD5; for R≥3, iterate 50 times.
  3. Truncate to `key_len` bytes → RC4 key.
  4. For R=2: RC4-decrypt /O once.
  5. For R≥3: 20 iterative passes in reverse order (i=19 down to 0),
     XOR each byte of RC4 key with i before each pass.

  ## Returns

  - `{:ok, padded_user_password}` — a 32-byte binary that is the padded user
    password (as if `PasswordPad.pad(user_password)` had been called).
  - `{:error, :encrypted_unsupported_handler}` — RC4 not available.
  """
  @spec derive_user_from_owner(binary(), StandardHandler.t()) ::
          {:ok, binary()} | {:error, :encrypted_unsupported_handler}
  def derive_user_from_owner(owner_password, %StandardHandler{} = handler)
      when is_binary(owner_password) do
    with :ok <- check_rc4() do
      key_len = key_length(handler)

      padded_owner = PasswordPad.pad(owner_password)

      # MD5(padded_owner); iterate 50x for R >= 3
      init_hash = :crypto.hash(:md5, padded_owner)
      rc4_key = maybe_iterate_full(init_hash, handler.revision, key_len)

      # Decrypt /O
      derived = decrypt_owner_entry(handler.o, rc4_key, handler.revision)
      {:ok, derived}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # R-ENC29: guard RC4 availability before any V1/V2 operation
  defp check_rc4 do
    if :rc4 in :crypto.supports(:ciphers) do
      :ok
    else
      {:error, :encrypted_unsupported_handler}
    end
  end

  # Compute key_len from handler.length; default to 16 if missing
  defp key_length(%StandardHandler{version: 1}), do: 5
  defp key_length(%StandardHandler{length: len}) when is_integer(len), do: div(len, 8)
  defp key_length(_), do: 16

  # Append the EncryptMetadata flag for R >= 4 when encrypt_metadata == false
  defp maybe_append_metadata_flag(md5_ctx, %StandardHandler{
         revision: r,
         encrypt_metadata: false
       })
       when r >= 4 do
    :crypto.hash_update(md5_ctx, <<0xFF, 0xFF, 0xFF, 0xFF>>)
  end

  defp maybe_append_metadata_flag(md5_ctx, _handler), do: md5_ctx

  # For R >= 3: iterate MD5 × 50 on first key_len bytes of the hash
  defp maybe_iterate(hash, revision, key_len) when revision >= 3 do
    Enum.reduce(1..50, hash, fn _i, acc ->
      :crypto.hash(:md5, binary_part(acc, 0, key_len))
    end)
  end

  defp maybe_iterate(hash, _revision, _key_len), do: hash

  # For Algorithm 7 step 2: iterate on full 16-byte hash (not truncated)
  defp maybe_iterate_full(hash, revision, key_len) when revision >= 3 do
    full_iterated =
      Enum.reduce(1..50, hash, fn _i, acc ->
        :crypto.hash(:md5, acc)
      end)

    binary_part(full_iterated, 0, key_len)
  end

  defp maybe_iterate_full(hash, _revision, key_len) do
    binary_part(hash, 0, key_len)
  end

  # Verify user password hash against /U (Algorithm 4 for R=2, Algorithm 5 for R>=3)
  defp verify_user(file_key, %StandardHandler{revision: 2, u: u}) do
    pad_const = PasswordPad.constant()
    expected = :crypto.crypto_one_time(:rc4, file_key, pad_const, true)
    expected == u
  end

  defp verify_user(file_key, %StandardHandler{revision: r, u: u, id: id}) when r >= 3 do
    pad_const = PasswordPad.constant()

    # MD5(pad_const ++ ID[0])
    md5_16 = :crypto.hash(:md5, pad_const <> id)

    # RC4-encrypt 16 bytes with file_key (pass 0)
    step0 = :crypto.crypto_one_time(:rc4, file_key, md5_16, true)

    # 19 more passes: i=1..19, key XOR i
    result =
      Enum.reduce(1..19, step0, fn i, acc ->
        xor_key = xor_key_with_i(file_key, i)
        :crypto.crypto_one_time(:rc4, xor_key, acc, true)
      end)

    # Compare to first 16 bytes of /U
    result == binary_part(u, 0, 16)
  end

  # Decrypt /O for Algorithm 7
  # R=2: single RC4 decrypt
  defp decrypt_owner_entry(o_bytes, rc4_key, 2) do
    :crypto.crypto_one_time(:rc4, rc4_key, o_bytes, true)
  end

  # R>=3: 20 iterative passes in reverse order (i=19 down to 0)
  defp decrypt_owner_entry(o_bytes, rc4_key, _r) do
    Enum.reduce(19..0//-1, o_bytes, fn i, acc ->
      xor_key = xor_key_with_i(rc4_key, i)
      :crypto.crypto_one_time(:rc4, xor_key, acc, true)
    end)
  end

  # XOR every byte of key with the integer i
  defp xor_key_with_i(key, i) do
    for <<b <- key>>, into: <<>>, do: <<Bitwise.bxor(b, i)>>
  end
end
