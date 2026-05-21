# `Pdf.Reader.Errors`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/errors.ex#L1)

Documents the full reason set returned in `{:error, reason}` from `Pdf.Reader`.

This module exports nothing — it is documentation only. Errors are bare atoms
or `{atom, details}` tuples returned in `{:error, _}`; they are NOT exception
structs. Pattern-match on them directly.

## Reason reference

- `:not_a_pdf` — file or binary does not begin with `%PDF-`.
- `{:unsupported_pdf_version, "X.Y"}` — version string is outside the
  1.0–2.0 range that this reader handles.
- `:malformed` — generic spec violation when no structured detail is
  available (e.g., truncated binary before `%%EOF`).
- `{:malformed, where, details}` — structured violation; `where` is one of
  `:trailer | :xref | :object | :stream | :content_stream | :cmap`;
  `details` is a map with at least `:offset` and `:expected` keys.
- `:encrypted_password_required` — PDF is encrypted; no password was supplied
  (or the empty password was tried and rejected). Caller should retry with
  `Pdf.Reader.open(bin, password: "the_password")`.
- `:encrypted_wrong_password` — password was supplied but authentication
  failed for both user and owner paths.
- `:encrypted_unsupported_handler` — the PDF uses an encryption handler that
  is not the Standard Security Handler (`/Filter` is not `/Standard`), or the
  `/V` version is unsupported (not in `{1, 2, 4, 5}`), or V5 with R=5
  (deprecated Acrobat X beta), or V1/V2 was requested on a runtime where
  `:rc4` is absent from `:crypto.supports(:ciphers)` (e.g., OpenSSL 3.x
  FIPS mode).
- `:io_error` — file read failed without a POSIX detail.
- `{:io_error, posix}` — file read failed; `posix` is a `File.posix()`
  atom such as `:enoent` or `:eacces`.
- `{:unsupported_filter, name}` — stream filter not in the supported set
  {FlateDecode, ASCII85Decode, ASCIIHexDecode, RunLengthDecode, LZWDecode};
  `name` is an atom.
- `{:unresolved_ref, {n, g}}` — indirect reference `n g R` is absent from
  the cross-reference table or points past end-of-file.
- `{:cmap_unsupported_subset, op}` — CMap stream uses a construct outside
  the `bfchar`/`bfrange` subset that this reader handles; `op` is an atom.
- `{:lzw_decode_error, kind}` — LZW bit stream is malformed; `kind` is an
  atom describing the failure (e.g., `:code_out_of_range`, `:premature_eod`).
- `{:flate_decode_error, kind}` — `:zlib` returned an error; `kind` is the
  zlib error term.
- `{:objstm_unsupported, kind}` — object stream (`/Type /ObjStm`) is
  malformed or refers to a nested ObjStm (illegal per spec).
- `:no_pages` — page tree is empty or structurally malformed.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
