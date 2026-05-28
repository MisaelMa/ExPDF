# `Pdf.Reader.Encryption.V5`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/encryption/v5.ex#L1)

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

# `authenticate_owner`

```elixir
@spec authenticate_owner(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
```

Authenticates an owner password for V5/R6 using Algorithm 9.

## Parameters

- `password` — the plaintext owner password (UTF-8 string; truncated to 127 bytes).
- `handler` — a `%StandardHandler{}` with `:revision`, `:u`, `:o`, and `:oe` populated.

## Returns

- `{:ok, file_key}` — password authenticated; `file_key` is the 32-byte file
  encryption key recovered by decrypting `/OE`.
- `:error` — authentication failed.
- `{:error, :encrypted_unsupported_handler}` — revision is not 6.

# `authenticate_user`

```elixir
@spec authenticate_user(binary(), Pdf.Reader.Encryption.StandardHandler.t()) ::
  {:ok, binary()} | :error | {:error, :encrypted_unsupported_handler}
```

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

# `decrypt_string`

```elixir
@spec decrypt_string(
  binary(),
  non_neg_integer(),
  non_neg_integer(),
  Pdf.Reader.Encryption.StandardHandler.t()
) :: {:ok, binary()} | :error
```

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*
