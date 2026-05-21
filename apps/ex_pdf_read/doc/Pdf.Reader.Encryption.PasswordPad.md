# `Pdf.Reader.Encryption.PasswordPad`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/encryption/password_pad.ex#L1)

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

# `constant`

```elixir
@spec constant() :: &lt;&lt;_::256&gt;&gt;
```

Returns the canonical 32-byte PDF password-padding constant.

Defined in PDF 1.7 § 7.6.3.3 as a fixed magic value used to pad short
passwords before they are fed into MD5 hashing.

# `pad`

```elixir
@spec pad(binary()) :: &lt;&lt;_::256&gt;&gt;
```

Pads or truncates `password` to exactly 32 bytes per PDF 1.7 § 7.6.3.3.

- If `password` is shorter than 32 bytes: appends bytes from `@pad_constant`
  until the result is 32 bytes long.
- If `password` is exactly 32 bytes: returns it unchanged.
- If `password` is longer than 32 bytes: truncates to the first 32 bytes.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
