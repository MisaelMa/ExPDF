defmodule Pdf.Reader.Encryption.V4 do
  @moduledoc """
  Implements PDF Standard Security Handler algorithms for V4 (Crypt Filters +
  AES-128 CBC) — revision R=4.

  ## Algorithms implemented

  | Algorithm | Description                                               | Function                  |
  |-----------|-----------------------------------------------------------|---------------------------|
  | Alg 6     | User password auth for V4/R=4                            | `authenticate_user/2`     |
  | Alg 7     | Owner password auth for V4/R=4                           | `authenticate_owner/2`    |
  | —         | Crypt Filter dispatch (CF dict → cipher atom)            | `select_crypt_filter/3`   |
  | —         | Stream decryption (AES-128-CBC or RC4, or passthrough)   | `decrypt_stream/5`        |
  | —         | String decryption (same as stream, uses str_filter)      | `decrypt_string/4`        |

  ## Algorithm 6 (V4 user password authentication, PDF 1.7 § 7.6.3.4)

  Identical to Algorithm 5 for V1V2/R≥3 — the V4 extension only adds the
  EncryptMetadata byte to Algorithm 2 when `/EncryptMetadata false`.  Both
  conditions are already handled by `V1V2.authenticate_user/2`, so Algorithm 6
  is implemented by direct delegation.

  ## Algorithm 7 (V4 owner password authentication)

  Also delegated to `V1V2.authenticate_owner/2` — same derivation path.

  ## Crypt Filters (PDF 1.7 § 7.6.5)

  V4 introduces per-stream encryption selection via the `/CF` dictionary.
  Each named entry in `/CF` carries a `/CFM` (Crypt Filter Method):

  | `/CFM` value | Cipher atom returned |
  |--------------|----------------------|
  | `None`       | `:identity`          |
  | `V2`         | `:rc4`               |
  | `AESV2`      | `:aes_128`           |
  | (unknown)    | `:identity`          |

  `/StmF` names the default filter for streams; `/StrF` for strings.  A
  stream can override via its own `/Filter` entry (last array element when
  the value is a list, or the single name when it is a `{:name, string}`).

  ## Stream and String Decryption

  Per-object key derivation (`ObjectKey.derive/4`) is applied for both RC4 and
  AES-128 ciphers.  For AES-128-CBC (AESV2):
  - First 16 bytes of the ciphertext blob are the IV.
  - Remaining bytes are the actual ciphertext.
  - PKCS7 padding is stripped and validated after decryption.
  - Invalid padding (last byte N is 0, > 16, or padding bytes don't all equal N)
    returns `:error` rather than raising (R-ENC14).

  For `:identity`, the bytes are returned unchanged (R-ENC15, R-ENC20).

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 7.6.3.3 algorithms 6, 7:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 7.6.5 — Crypt Filters:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - NIST FIPS 197 — AES:
    https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
  - NIST SP 800-38A — CBC mode:
    https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf
  - Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference impl):
    https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js
  - Erlang OTP `:crypto` algorithm details:
    https://www.erlang.org/docs/27/apps/crypto/algorithm_details
  """

  alias Pdf.Reader.Encryption.{ObjectKey, StandardHandler, V1V2}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Authenticates a user password for a V4/R=4 handler (Algorithm 6).

  Delegates directly to `V1V2.authenticate_user/2` — Algorithm 2 already
  handles the R=4 EncryptMetadata extension.

  ## Returns

  - `{:ok, file_key}` — password authenticated.
  - `:error` — wrong password.
  - `{:error, :encrypted_unsupported_handler}` — RC4 unavailable at runtime.
  """
  @spec authenticate_user(binary(), StandardHandler.t()) ::
          {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
  def authenticate_user(password, %StandardHandler{revision: 4} = handler)
      when is_binary(password) do
    V1V2.authenticate_user(password, handler)
  end

  @doc """
  Authenticates an owner password for a V4/R=4 handler (Algorithm 7).

  Delegates directly to `V1V2.authenticate_owner/2`.

  ## Returns

  - `{:ok, file_key}` — owner password authenticated.
  - `:error` — wrong password.
  - `{:error, :encrypted_unsupported_handler}` — RC4 unavailable at runtime.
  """
  @spec authenticate_owner(binary(), StandardHandler.t()) ::
          {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
  def authenticate_owner(password, %StandardHandler{revision: 4} = handler)
      when is_binary(password) do
    V1V2.authenticate_owner(password, handler)
  end

  @doc """
  Selects the effective crypt filter cipher for a stream or string.

  Per PDF 1.7 § 7.6.5.4, the resolution order is:

  1. Check the stream's own `/Filter` entry for a per-stream crypt filter
     override (last element when it is a list; the name itself when it is a
     single `{:name, string}`).
  2. If no per-stream override is found, use `handler.stm_filter` (for
     `:stream`) or `handler.str_filter` (for `:string`).
  3. Look up the resolved filter name in `handler.cf` and map its `/CFM`
     to a cipher atom.

  Filter name `/Identity` (or CFM `None`) always resolves to `:identity`.

  ## Parameters

  - `stream_dict` — the stream or object dictionary (plain `%{}` map).
  - `handler` — a `%StandardHandler{}` with `:cf`, `:stm_filter`, `:str_filter` set.
  - `kind` — `:stream` or `:string`.

  ## Returns

  `:identity | :rc4 | :aes_128`
  """
  @spec select_crypt_filter(map(), StandardHandler.t(), :stream | :string) ::
          :identity | :rc4 | :aes_128
  def select_crypt_filter(stream_dict, %StandardHandler{} = handler, kind)
      when is_map(stream_dict) and kind in [:stream, :string] do
    filter_name = effective_filter_name(stream_dict, handler, kind)
    resolve_cfm(filter_name, handler.cf)
  end

  @doc """
  Decrypts a stream ciphertext blob using the effective crypt filter.

  The `security_handler` must have `:file_key` populated (set after authentication).

  ## Parameters

  - `bytes` — raw stream bytes (IV + ciphertext for AES, pure ciphertext for RC4).
  - `stream_dict` — the stream dictionary for per-stream filter override lookup.
  - `obj_num` — PDF object number.
  - `gen_num` — PDF generation number.
  - `security_handler` — a `%StandardHandler{}` with `:file_key` populated.

  ## Returns

  - `{:ok, plaintext}` — successfully decrypted.
  - `:error` — invalid PKCS7 padding (AES only) or stream too short for IV.
  """
  @spec decrypt_stream(binary(), map(), non_neg_integer(), non_neg_integer(), StandardHandler.t()) ::
          {:ok, binary()} | :error
  def decrypt_stream(bytes, stream_dict, obj_num, gen_num, %StandardHandler{} = handler)
      when is_binary(bytes) do
    cipher = select_crypt_filter(stream_dict, handler, :stream)
    do_decrypt(bytes, obj_num, gen_num, handler.file_key, cipher)
  end

  @doc """
  Decrypts a string ciphertext using the effective string crypt filter.

  Uses `str_filter` for filter resolution (same decryption logic as streams).

  ## Parameters

  - `bytes` — raw string bytes (IV + ciphertext for AES, pure ciphertext for RC4).
  - `obj_num` — PDF object number.
  - `gen_num` — PDF generation number.
  - `security_handler` — a `%StandardHandler{}` with `:file_key` populated.

  ## Returns

  - `{:ok, plaintext}` — successfully decrypted.
  - `:error` — invalid PKCS7 padding (AES only) or insufficient bytes.
  """
  @spec decrypt_string(binary(), non_neg_integer(), non_neg_integer(), StandardHandler.t()) ::
          {:ok, binary()} | :error
  def decrypt_string(bytes, obj_num, gen_num, %StandardHandler{} = handler)
      when is_binary(bytes) do
    cipher = select_crypt_filter(%{}, handler, :string)
    do_decrypt(bytes, obj_num, gen_num, handler.file_key, cipher)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Dispatch decryption by cipher atom
  defp do_decrypt(bytes, _obj_num, _gen_num, _file_key, :identity) do
    {:ok, bytes}
  end

  defp do_decrypt(bytes, obj_num, gen_num, file_key, :rc4) do
    key = ObjectKey.derive(file_key, obj_num, gen_num, :rc4)
    plaintext = :crypto.crypto_one_time(:rc4, key, bytes, false)
    {:ok, plaintext}
  end

  defp do_decrypt(bytes, obj_num, gen_num, file_key, :aes_128)
       when byte_size(bytes) >= 16 do
    key = ObjectKey.derive(file_key, obj_num, gen_num, :aes_128)
    # First 16 bytes are the IV; remainder is the ciphertext
    <<iv::binary-size(16), ciphertext::binary>> = bytes
    decrypted = :crypto.crypto_one_time(:aes_128_cbc, key, iv, ciphertext, false)
    pkcs7_unpad(decrypted)
  end

  defp do_decrypt(_bytes, _obj_num, _gen_num, _file_key, :aes_128) do
    # Stream too short to contain even the IV
    :error
  end

  # Determine the effective filter name for a stream/string.
  # Per-stream /Filter override takes priority over the document-level /StmF or /StrF.
  defp effective_filter_name(stream_dict, handler, kind) do
    case extract_per_stream_filter(stream_dict) do
      {:ok, name} ->
        name

      :none ->
        case kind do
          :stream -> handler.stm_filter
          :string -> handler.str_filter
        end
    end
  end

  # Extract a per-stream crypt filter name from the stream dictionary's /Filter entry.
  # Per PDF 1.7 § 7.6.5.4:
  # - If /Filter is a list, the last element is the crypt filter name.
  # - If /Filter is a single {:name, string}, that is the filter name.
  # Returns {:ok, name} or :none.
  defp extract_per_stream_filter(stream_dict) do
    case Map.get(stream_dict, "Filter") do
      list when is_list(list) and length(list) > 0 ->
        case List.last(list) do
          {:name, name} -> {:ok, name}
          _ -> :none
        end

      {:name, name} ->
        {:ok, name}

      _ ->
        :none
    end
  end

  # Resolve a filter name to a cipher atom via the /CF dictionary.
  # "Identity" (and CFM "None") always → :identity.
  defp resolve_cfm("Identity", _cf), do: :identity

  defp resolve_cfm(nil, _cf), do: :identity

  defp resolve_cfm(name, cf) when is_map(cf) do
    case Map.get(cf, name) do
      cf_entry when is_map(cf_entry) ->
        cfm_to_atom(Map.get(cf_entry, "CFM"))

      _ ->
        # Filter name not found in /CF → treat as Identity (no decryption)
        :identity
    end
  end

  defp resolve_cfm(_name, _cf), do: :identity

  # Map a /CFM value to a cipher atom
  defp cfm_to_atom({:name, "AESV2"}), do: :aes_128
  defp cfm_to_atom({:name, "V2"}), do: :rc4
  defp cfm_to_atom({:name, "None"}), do: :identity
  defp cfm_to_atom(_), do: :identity

  # PKCS7 unpadding with full validation (R-ENC14).
  # Returns {:ok, plaintext} or :error if padding is invalid.
  defp pkcs7_unpad(data) when is_binary(data) and byte_size(data) > 0 do
    n = :binary.last(data)
    size = byte_size(data)

    cond do
      n == 0 or n > 16 or n > size ->
        :error

      true ->
        {plaintext, padding} = :erlang.split_binary(data, size - n)

        if :binary.bin_to_list(padding) |> Enum.all?(&(&1 == n)) do
          {:ok, plaintext}
        else
          :error
        end
    end
  end

  defp pkcs7_unpad(_), do: :error
end
