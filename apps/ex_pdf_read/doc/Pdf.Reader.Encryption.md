# `Pdf.Reader.Encryption`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/encryption.ex#L1)

Facade module for PDF Standard Security Handler authentication and decryption.

Dispatches to the appropriate version-specific module (`V1V2`, `V4`, `V5`)
based on the `/V` field of the parsed `%StandardHandler{}` struct.

This module does NOT parse the Encrypt dict — that is handled by
`Pdf.Reader.Encryption.StandardHandler.parse/2`. This module only:

1. Dispatches `unlock/3` to the correct version module.
2. Returns the handler with `:file_key` populated on success.

## Authentication flow

1. Try user password via `authenticate_user/2` for the detected version.
2. If that fails (`:error`), try owner password via `authenticate_owner/2`.
3. Return `{:ok, %StandardHandler{file_key: key}}` or `:error`.

## Supported versions

| `/V` | Module      | Revision |
|------|-------------|----------|
|  1   | `V1V2`      | R=2      |
|  2   | `V1V2`      | R=3/4    |
|  4   | `V4`        | R=4      |
|  5   | `V5`        | R=6 only |

V5/R5 (deprecated Acrobat X beta) is rejected by `V5.authenticate_user/2`
with `{:error, :encrypted_unsupported_handler}` per R-ENC25.

## Spec references

- PDF 1.7 (ISO 32000-1) § 7.6 — Standard Security Handler (V1/V2/V4):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 2.0 (ISO 32000-2) § 7.6 — Standard Security Handler (V5/R6):
  https://www.pdfa.org/wp-content/uploads/2023/04/ISO_32000_2_2020_PDF_2.0_FDIS.pdf
- Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference implementation):
  https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js

# `unlock`

```elixir
@spec unlock(binary(), Pdf.Reader.Encryption.StandardHandler.t(), map()) ::
  {:ok, Pdf.Reader.Encryption.StandardHandler.t()}
  | :error
  | {:error, :encrypted_unsupported_handler}
```

Attempts to unlock an encrypted PDF handler with the given password.

Tries the password as user, then as owner. Returns the handler with
`:file_key` populated on success.

## Parameters

- `password` — the plaintext password string.
- `handler` — a `%StandardHandler{}` parsed from the Encrypt dict (`:file_key` is nil).
- `_doc` — reserved for future use (e.g., doc reference); ignored for now.

## Returns

- `{:ok, %StandardHandler{file_key: key}}` — authenticated; key is populated.
- `:error` — wrong password (tried as both user and owner).
- `{:error, :encrypted_unsupported_handler}` — version unsupported or RC4 unavailable.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
