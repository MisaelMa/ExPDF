# `Pdf.Reader.Encryption.StandardHandler`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/encryption/standard_handler.ex#L1)

Parses the PDF `/Encrypt` dictionary into a `%StandardHandler{}` struct.

Supports Standard Security Handler revisions R=2 (V=1), R=3 (V=2), R=4 (V=4,
Crypt Filters + AES-128), and R=6 (V=5, AES-256, PDF 2.0).  Any other
`/Filter` value returns `{:error, :encrypted_unsupported_handler}`.

This module is a pure data-extraction layer.  It does NOT:
- Validate `/O` or `/U` password hashes.
- Derive the file encryption key.
- Perform any cryptographic operations.

Those operations are handled by `Pdf.Reader.Encryption.V1V2`,
`Pdf.Reader.Encryption.V4`, and `Pdf.Reader.Encryption.V5`.

## SecurityHandler struct fields

| Field              | Source                        | Default      |
|--------------------|-------------------------------|--------------|
| `:version`         | `/V`                          | `nil`        |
| `:revision`        | `/R`                          | `nil`        |
| `:length`          | `/Length`                     | `nil`        |
| `:o`               | `/O` (raw bytes, unwrapped)   | `nil`        |
| `:u`               | `/U` (raw bytes, unwrapped)   | `nil`        |
| `:oe`              | `/OE` (V5 only)               | `nil`        |
| `:ue`              | `/UE` (V5 only)               | `nil`        |
| `:perms`           | `/Perms` (V5 only, 16 bytes)  | `nil`        |
| `:p`               | `/P` (32-bit signed integer)  | `nil`        |
| `:cf`              | `/CF` sub-dict (V4/V5)        | `%{}`        |
| `:stm_filter`      | `/StmF` name (V4/V5)          | `nil`        |
| `:str_filter`      | `/StrF` name (V4/V5)          | `nil`        |
| `:encrypt_metadata`| `/EncryptMetadata` (V4+)      | `true`       |
| `:filter`          | `/Filter` name string         | `nil`        |
| `:file_key`        | populated after authentication | `nil`        |
| `:id`              | `/ID[0]` from trailer         | `nil`        |

## Spec references
- PDF 1.7 (ISO 32000-1) § 7.6.3.1 — Standard Security Handler:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 7.6.3.3 — Encryption Key Algorithm (R=2/3/4):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 2.0 (ISO 32000-2) § 7.6.4 — Standard Security Handler (R=6, V=5):
  https://www.pdfa.org/wp-content/uploads/2023/04/ISO_32000_2_2020_PDF_2.0_FDIS.pdf
- Mozilla pdf.js src/core/crypto.js (Apache-2.0 reference implementation):
  https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js

# `t`

```elixir
@type t() :: %Pdf.Reader.Encryption.StandardHandler{
  cf: %{required(String.t()) =&gt; map()},
  encrypt_metadata: boolean(),
  file_key: binary() | nil,
  filter: String.t() | nil,
  id: binary() | nil,
  length: non_neg_integer() | nil,
  o: binary() | nil,
  oe: binary() | nil,
  p: integer() | nil,
  perms: binary() | nil,
  revision: 2 | 3 | 4 | 6 | nil,
  stm_filter: String.t() | nil,
  str_filter: String.t() | nil,
  u: binary() | nil,
  ue: binary() | nil,
  version: 1 | 2 | 4 | 5 | nil
}
```

# `parse`

```elixir
@spec parse(map(), binary()) :: {:ok, t()} | {:error, :encrypted_unsupported_handler}
```

Parses an Encrypt dict map (as returned by `Pdf.Reader.Parser`) into a
`%StandardHandler{}` struct.

## Parameters

- `encrypt_dict` — a plain `%{}` map where values follow Parser tagging
  conventions: integers as integers, names as `{:name, string}`, byte strings
  as `{:string, binary}` or `{:hex_string, binary}`, booleans as booleans,
  sub-dicts as plain maps.
- `doc_id` — the raw binary of `/ID[0]` from the document trailer.  Stored on
  the struct as `:id` for use by key-derivation modules.

## Returns

- `{:ok, %StandardHandler{}}` — for `/Filter /Standard` dicts.
- `{:error, :encrypted_unsupported_handler}` — for any other `/Filter` value,
  or when `/Filter` is absent.

Note: the `:file_key` field is always `nil` on return.  Authentication and
key derivation are handled by V1V2/V4/V5 modules.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
