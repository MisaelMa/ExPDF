# `Pdf.Reader.Encryption.V1V2`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/encryption/v1v2.ex#L1)

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

# `authenticate_owner`

```elixir
@spec authenticate_owner(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
```

Derives the padded user password from the owner password using Algorithm 7,
then authenticates via `authenticate_user/2`.

## Returns

- `{:ok, file_key}` — owner password authenticated.
- `:error` — owner password authentication failed.
- `{:error, :encrypted_unsupported_handler}` — RC4 not available.

# `authenticate_user`

```elixir
@spec authenticate_user(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
```

Authenticates a user password against the `/U` value in the handler.

Uses Algorithm 4 for R=2 and Algorithm 5 for R≥3.

## Returns

- `{:ok, file_key}` — password authenticated; `file_key` is the derived
  file encryption key (5 bytes for V1, up to 16 bytes for V2/V4).
- `:error` — authentication failed (wrong password).
- `{:error, :encrypted_unsupported_handler}` — RC4 not available on this
  runtime (per R-ENC29 / S-ENC14).

# `decrypt_stream`

```elixir
@spec decrypt_stream(
  binary(),
  map(),
  non_neg_integer(),
  non_neg_integer(),
  Pdf.Reader.Encryption.StandardHandler.t()
) :: {:ok, binary()} | {:error, :encrypted_unsupported_handler}
```

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

# `decrypt_string`

```elixir
@spec decrypt_string(
  binary(),
  non_neg_integer(),
  non_neg_integer(),
  Pdf.Reader.Encryption.StandardHandler.t()
) :: {:ok, binary()} | {:error, :encrypted_unsupported_handler}
```

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

# `derive_file_key`

```elixir
@spec derive_file_key(binary(), Pdf.Reader.Encryption.StandardHandler.t()) :: binary()
```

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

# `derive_user_from_owner`

```elixir
@spec derive_user_from_owner(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | {:error, :encrypted_unsupported_handler}
```

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*
