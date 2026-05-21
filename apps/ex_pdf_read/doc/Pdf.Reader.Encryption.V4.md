# `Pdf.Reader.Encryption.V4`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/encryption/v4.ex#L1)

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

# `authenticate_owner`

```elixir
@spec authenticate_owner(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
```

Authenticates an owner password for a V4/R=4 handler (Algorithm 7).

Delegates directly to `V1V2.authenticate_owner/2`.

## Returns

- `{:ok, file_key}` — owner password authenticated.
- `:error` — wrong password.
- `{:error, :encrypted_unsupported_handler}` — RC4 unavailable at runtime.

# `authenticate_user`

```elixir
@spec authenticate_user(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
```

Authenticates a user password for a V4/R=4 handler (Algorithm 6).

Delegates directly to `V1V2.authenticate_user/2` — Algorithm 2 already
handles the R=4 EncryptMetadata extension.

## Returns

- `{:ok, file_key}` — password authenticated.
- `:error` — wrong password.
- `{:error, :encrypted_unsupported_handler}` — RC4 unavailable at runtime.

# `decrypt_stream`

```elixir
@spec decrypt_stream(
  binary(),
  map(),
  non_neg_integer(),
  non_neg_integer(),
  Pdf.Reader.Encryption.StandardHandler.t()
) :: {:ok, binary()} | :error
```

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

# `decrypt_string`

```elixir
@spec decrypt_string(
  binary(),
  non_neg_integer(),
  non_neg_integer(),
  Pdf.Reader.Encryption.StandardHandler.t()
) :: {:ok, binary()} | :error
```

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

# `select_crypt_filter`

```elixir
@spec select_crypt_filter(
  map(),
  Pdf.Reader.Encryption.StandardHandler.t(),
  :stream | :string
) ::
  :identity | :rc4 | :aes_128
```

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*
