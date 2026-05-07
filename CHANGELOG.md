# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased — pdf-reader-resource-inheritance-multilevel

### Fixed

- **Cyclic /Parent infinite loop** — `resolve_page_resources/4` now carries a
  `visited` `MapSet` of `{obj_num, gen_num}` xref refs during each `/Parent`-chain
  walk. If a ref is encountered a second time (direct self-ref or transitive cycle),
  the walk is silently terminated and `%{}` is returned. Prevents corrupt PDFs from
  hanging the reader indefinitely.

### Added

- **Per-leaf-page resource cache** — resolved `/Resources` maps are now stored in
  `doc.cache` under `{:page_resources, {n, g}}` keyed by the leaf page's xref ref.
  Subsequent calls for the same page (e.g. a second `read_text/1` call on an open
  doc) skip the `/Parent`-chain walk entirely and return the cached value.

### Note

- **Moduledoc clarified** — removed the stale "Known limitations" entry that stated
  resource inheritance was limited to one level of parent-chain walk. The full
  recursive walk has been in place since Phase 1.1; only the documentation was wrong.
  Added PDF 1.7 § 7.7.3 and § 7.7.3.4 spec references.

## Unreleased — fix-writer-set-info-state

### Fixed

- **Info dict lost after page mutations** — `Pdf.set_info/2` (and its single-key
  variants `set_title/2`, `set_author/2`, etc.) stores metadata by updating
  `document.objects`. However, `Page` carries its own copy of `objects` that was
  snapshotted at page-creation time. Any subsequent page mutation (`set_font`,
  `text_at`, …) calls `sync_page/2`, which replaces `document.objects` with
  `page.objects` — silently discarding the info update. The fix propagates the
  info-dict change into `document.current.objects` inside `put_info/2`, so both
  copies stay in sync and `sync_page/2` no longer clobbers metadata.

## Unreleased — pdf-reader-form-xobject-recursion (Phase 3)

### Added — Phase 3 (pdf-reader-form-xobject-recursion)

- **Form XObject recursion** — `Do` operators referencing `/Type /XObject
  /Subtype /Form` are now recursed into transparently. Text and images inside
  Forms (headers, footers, repeated logos, templated form fields) appear in
  `Pdf.Reader.read_text/2`, `read_text_with_positions/1`, and `read_images/1`
  output. Previously these objects were emitted as `{:deferred, :form_xobject,
  name}` events and silently dropped — that behavior is REPLACED.
- **CTM × `/Matrix` inheritance** — child Form's CTM is `Form.Matrix × parent
  CTM at time of Do`. Graphics state is saved on entry and restored on exit
  (effectively `q ... Q` around the form).
- **Resource merging** — Form's `/Resources` is shallow-merged with the page's
  resources (Form wins on key collision). Per-Form font decoders are built via
  `Pdf.Reader.Font.build_decoders_for_resources/2` and benefit from the
  existing `Document.cache` `{:font_decoder, font_ref}` cache.
- **Cycle detection** — interpreter state carries a `:visited` `MapSet` of
  `{obj_num, gen_num}` xref keys, threaded forward into child states. When a
  Form references an already-visited Form (directly or transitively), an
  internal `{:cycle_detected, ref}` event is emitted and recursion is skipped.
- **Depth cap** — recursion is capped at `@max_form_depth 8`. Beyond that, an
  internal `{:max_depth_exceeded, ref}` event is emitted and the Form is
  skipped.
- **Image bubble-up** — images embedded inside Form XObjects bubble up to the
  parent's event stream and appear in `read_images/1` output, with CTM
  reflecting the full transform (Form.Matrix × parent CTM × image local CTM).
- **Internal/cycle/depth events dropped from text output** — the new
  `{:cycle_detected, _}` and `{:max_depth_exceeded, _}` event types flow
  through `Pdf.Reader.ContentStream.interpret/3`'s output but are silently
  dropped by `events_to_text_runs/2`. Public `read_text*` API surface
  unchanged.

### Modified — Phase 3

- `Pdf.Reader.ContentStream.interpret/3` — public arity and return shape
  unchanged (backward-compat). New private `do_interpret_with_doc/5` for the
  recursive path; `extract_page_runs/3` and `extract_page_images/3` now use it.
- `Pdf.Reader.Image` and `Pdf.Reader.TextRun` events from inside Forms are
  appended to the parent page's event list.
- `build_xobjects_map/1` simplified — passes raw `{:ref, n, g}` refs from
  `resources["XObject"]` instead of pre-classifying as `:form`. ContentStream
  classifies on demand inside `Do`.

### Out of scope (Phase 3)

- BBox clipping of Form contents — text outside a Form's `/BBox` is still
  extracted (presentational concern, not data extraction).
- Pattern XObject recursion — `/Type /Pattern` objects referenced via `Do`
  are skipped.
- Multi-level page-tree resource inheritance (still one-level walk only).
- AcroForm interactive field extraction.

### Internal — Phase 3

- Test suite: 756 tests, 0 failures (738 default + 18 `@tag :fixtures`).
- Strict TDD applied throughout (red → green → refactor per task).
- Spec-driven via SDD (`sdd/pdf-reader-form-xobject-recursion/*` artifacts in
  engram).
- `Pdf.Reader.ContentStream` `@moduledoc` cites PDF 1.7 § 8.10 (Form XObjects),
  § 8.10.2 (Form Dictionaries), § 8.4 (Coordinate Systems), § 8.8 (External
  Objects / Do operator) plus pdf.js + pdfminer-six reference impls.

---

## Unreleased — pdf-reader-encryption (Phase 2)

### Added — Phase 2 (pdf-reader-encryption)

- **Standard Security Handler** support — encrypted PDFs are now READABLE via
  `Pdf.Reader.open/2` when the correct password is provided (or empty for
  metadata-protection cases). Implements all four spec versions:
  - **V1 / R=2** — RC4 40-bit (legacy)
  - **V2 / R=3** — RC4 up to 128-bit (most common pre-2008)
  - **V4 / R=4** — Crypt Filters + AES-128 (PDF 1.6+)
  - **V5 / R=6** — AES-256 + SHA-256/384/512 mixing (PDF 2.0 / Acrobat X+)
- **`Pdf.Reader.open/2`** with `password: String.t()` opt (default `""`).
  - Always tries empty password first (metadata-protection auto-unlock).
  - If non-empty password supplied, tries as user → owner password.
  - `Pdf.Reader.open/1` retained — delegates to `open/2` with empty opts.
- **New error atoms** in `Pdf.Reader.reason/0`:
  - `:encrypted_password_required` — no password supplied, empty failed.
  - `:encrypted_wrong_password` — supplied password rejected as user AND owner.
  - `:encrypted_unsupported_handler` — `/Filter != /Standard`, V5/R5 (deprecated),
    or RC4 unavailable on the runtime.
  - The legacy `:encrypted` atom is REMOVED (existing test updated to assert
    the new atom).
- **`Pdf.Reader.Document` struct** gained `:encryption` field
  (`%StandardHandler{}` when encrypted, `nil` otherwise).
- **Decryption hook** integrated transparently in
  `Pdf.Reader.ObjectResolver.resolve_in_use/3` only — `resolve_compressed/3`
  is left untouched (object-stream contents are decrypted ONCE at the
  containing-stream level; double-decryption would corrupt them).
- **Per-object encryption key** derivation per PDF 1.7 § 7.6.2 for V1/V2/V4
  (file key + obj_num + gen_num + optional `sAlT` literal → MD5 → truncate).
  V5 uses the file encryption key directly.
- **Crypt Filter `/Identity`** honored — V4 streams marked `/Identity` are
  passed through plaintext (common XMP metadata pattern).
- **`/EncryptMetadata false`** honored — when set in the Encrypt dict, the
  catalog's `/Metadata` stream is read as plaintext regardless of the
  default Stream Filter.
- **`mix.exs`** — `:crypto` added to `extra_applications` (required at
  release time; the OTP `:crypto` app is stdlib, not a Hex dep).
- New modules: `Pdf.Reader.Encryption` (facade), `Pdf.Reader.Encryption.{PasswordPad, ObjectKey, StandardHandler, V1V2, V4, V5}`.

### Known Limitations (Phase 2, carried forward)

- **End-to-end V4/V5 round-trip integration tests deferred** — algorithm-level
  unit tests (73 total across V1V2/V4/V5) verify each cipher against published
  vectors from Mozilla pdf.js `crypto_spec.js`, cross-checked with Node.js.
  V2/R3 is fully covered end-to-end via `craft_rc4_v2_pdf/1` (round-trip from
  hand-crafted PDF through `open/2` → `read_text/1`). V4/V5 dispatch through
  the resolver hook is unit-validated but lacks a full hand-crafted PDF
  round-trip fixture. Planned as `pdf-reader-encryption-fixtures-handcraft`.
- **Real-world fixture PDFs not committed** — would require `qpdf` as a
  build/test dependency, which contradicts the project's "native only, zero
  external dependencies" principle. Planned as a separate optional change
  if/when the constraint is relaxed.
- **R5** (deprecated V5 variant) — unsupported by design. PDFs with `V=5 R=5`
  return `{:error, :encrypted_unsupported_handler}`.
- **Public-Key Security Handler** (X.509 cert-based, `/Filter /Adobe.PubSec`
  or similar) — not supported. Returns `:encrypted_unsupported_handler`.
- **Permission flag enforcement** — flags are read but NOT enforced. We are
  a reader; downstream tools may choose to honor `/P` bits.
- **RC4 availability** — runtime dependent on OpenSSL configuration. On
  systems where RC4 is disabled (some OpenSSL 3 builds), V1/V2 PDFs return
  `:encrypted_unsupported_handler`. AES paths (V4/V5) work everywhere.

### Internal — Phase 2

- Test suite: 726 tests, 0 failures (708 default + 18 `@tag :fixtures`).
- 73 unit tests across V1V2/V4/V5 verify algorithms 2, 4, 5, 6, 7, 8, 9,
  10 against vectors sourced from Mozilla pdf.js `test/unit/crypto_spec.js`
  (Apache-2.0). Each vector independently re-computed with Node.js `crypto`
  and `:crypto` Erlang to confirm parity.
- Strict TDD applied throughout (red → green → refactor per task).
- Spec-driven via SDD (`sdd/pdf-reader-encryption/*` artifacts in engram).
- All algorithm modules cite canonical spec URLs (PDF 1.7/2.0, NIST FIPS 197,
  NIST SP 800-38A, RFC 1321) in `@moduledoc`.

---

## Unreleased — pdf-reader-cascade-wire (Phase 1.1)

### Added — Phase 1.1 (pdf-reader-cascade-wire)

- **Encoding cascade wired** through `read_text/2` and `read_text_with_positions/1` —
  text is now decoded to Unicode (was raw bytes in Phase 1). Per-font cascade order:
  ToUnicode CMap → /Differences + AGL → base encoding (WinAnsi/MacRoman/Standard) → U+FFFD.
- **Per-font decoder construction with cache** — `Pdf.Reader.Font.build_decoder/2` builds
  closures per font dict; decoders are cached in `Document.cache` keyed by
  `{:font_decoder, font_ref}` (indirect-ref fonts only; inline font dicts are not cached).
- **`Tf` operator switches active decoder** mid-content-stream — font changes in the
  stream are respected; each text operation uses the decoder for the currently active font.
- **XMP metadata parsing** via `:xmerl` (OTP stdlib) — `read_metadata/1` merges XMP with
  `/Info`; XMP wins on conflict (PDF 1.7 § 14.3.2). Recognized namespaces: dc:, xmp:, pdf:.
  Malformed XMP falls back to `/Info`-only silently.
- **`Pdf.Reader.Image` struct** gained `:ctm`, `:render_width`, `:render_height`,
  `:rotation_radians` fields. CTM decomposition follows PDF 1.7 § 8.3.3 and § 8.9.5.
- **Resource inheritance** — one-level parent-chain walk added to `resolve_page_resources/2`
  so writer-built PDFs (which store resources on the Pages parent node, not the leaf page)
  extract text and images correctly.
- New modules: `Pdf.Reader.Font`, `Pdf.Reader.XMP`
- New fixture: `test/fixtures/images/tiny.jpg` (32×32 px, ~900 B, public-domain JPEG
  from picsum.photos — used by image CTM integration tests)

### Known Limitations (Phase 1.1, carried forward)

- **Resource inheritance** — only one level of parent-chain walk is implemented. PDFs with
  deeply nested page trees that store resources two or more levels above the leaf page may
  produce empty text. Planned as `pdf-reader-resource-inheritance` change.
- **Per-glyph advance via `/Widths`** — glyph advance is approximated as uniform
  (`char_count × font_size`). Per-glyph widths are a separate change.
- **Form XObject `Do` recursion** — content inside form XObjects (`/Type /Form`) is not
  extracted. Planned for Phase 3.
- **CID fonts beyond ToUnicode** — CID-keyed fonts without a `/ToUnicode` CMap produce
  U+FFFD substitutions. Planned for Phase 3.
- **CCITTFaxDecode, JBIG2Decode, JPXDecode** — not supported; these require third-party
  C libraries and are outside scope.

### Internal — Phase 1.1

- Test suite: 616 tests, 0 failures (598 default + 18 `@tag :fixtures`)
- Strict TDD applied throughout (red → green → refactor per task)
- Spec-driven via SDD (`sdd/pdf-reader-cascade-wire/*` artifacts in engram)

---

## Unreleased — pdf-reader-core (Phase 1)

### Added

- `Pdf.Reader.open/1`, `read_text/2`, `read_text_with_positions/1`, `read_images/1`,
  `read_metadata/1`, `page_count/1`, `close/1` — and bang variants (`open!/1`, etc.)
- Stream filter pipeline:
  - `FlateDecode` with PNG predictors 1–4 and 10–14 and TIFF Predictor 2 (horizontal differencing)
  - `ASCII85Decode` with `z` shortcut and `~>` EOD marker
  - `ASCIIHexDecode` with whitespace tolerance and `>` EOD
  - `RunLengthDecode` (128 = EOD, 0–127 = literal, 129–255 = repeat)
  - `LZWDecode` with variable-width codes (9–12 bit), EarlyChange 0 and 1
- Cross-reference table support: classic xref (PDF 1.0–1.4) AND xref streams (PDF 1.5+)
  with `/Prev` chain merging and hybrid chains (mixed classic + stream)
- Object stream (`/Type /ObjStm`) decoding via `Pdf.Reader.ObjectStream`
- Encoding cascade (per-glyph): ToUnicode CMap → /Differences + Adobe Glyph List →
  base encoding (WinAnsi / MacRoman / StandardEncoding) → `U+FFFD` with diagnostic sentinel
- Bundled Adobe Glyph List 2.0 as a compile-time module (~4 500 entries, BSD-licensed)
- Public-domain encoding tables:
  - Apple ROMAN.TXT (canonical Mac Roman mapping)
  - PDF 1.7 Annex D.2 StandardEncoding (cross-checked against Mozilla pdf.js)
- Lazy indirect-object resolver with pure `Map` cache — no GenServer, no Agent
- Pure tagged-tuple internal value model:
  `{:ref, n, g}`, `{:name, _}`, `{:string, _}`, `{:hex_string, _}`,
  `{:stream, dict, body}`, plain `%{}` for dicts, plain lists for arrays

### Known Limitations (Phase 1)

- No encryption support — encrypted PDFs return `{:error, :encrypted}` (deferred to Phase 2)
- No CID fonts beyond ToUnicode-mapped glyphs (deferred to Phase 3)
- No `CCITTFaxDecode`, `JBIG2Decode`, or JPEG 2000 image filters — these require
  third-party C libraries and are outside scope
- No AcroForm or XFA form field extraction
- No OCR or scanned-PDF text extraction — impossible without third parties
- Form XObject (`Do` operator) is recognised but not recursed; content is not extracted
- Glyph advance approximation: uses `char_count × font_size` instead of per-glyph
  `/Widths`; start-of-run position is exact, inter-run drift is possible for proportional fonts
- CMap multi-codepoint mappings (ligatures): only the first codepoint is used
- Malformed PDFs return strict `{:error, :malformed}` — no partial-recovery mode
- XMP metadata streams are not parsed; `read_metadata/1` reads only the `/Info` dictionary

### Internal

- Test suite: 550 tests, 0 failures (541 default + 9 `@tag :fixtures`)
- Strict TDD applied throughout (red → green → refactor per task)
- Spec-driven via SDD (`sdd/pdf-reader-core/*` artifacts in engram)

---

## 0.7.1 (2024-07-23)

- Fix memory leak when cleaning up a PDF process

## 0.7.0 (2024-07-12)

- Add `autoprint/1` to automatically open the print dialog in a browser

## 0.6.1 (2023-01-19)

- Fix bug with zero width strings and empty rows (also fixes [#24])
- Fix issue with nil cap height [#35]
- Raise RuntimeError when attempting to add text without a font [#36]
- Fix typespec for `text_wrap/5` [#37]

## 0.6.0 (2021-12-07)

- Add `:odd` and `:even` to `:row_style` on table with a lower precedence than indexed styles
- Fix bug where only the first non-WinAnsi character was replaced [#32]

## 0.5.0 (2020-12-02)

- Catch errors raised within the GenServer and re-raise them in the calling process

## 0.4.0 (2020-08-12)

- Add `:encoding_replacement_character` option to supply a replacement character when encoding fails
- Add `:allow_row_overflow` option to `Pdf.table/4` to allow row contents to be split across pages

## 0.3.7 (2020-04-29)

- Bug fix: Fix memory leak by stopping internal processes

## 0.3.6 (2020-04-22)

- Bug fix: Correctly handle encoded text as binary, not UTF-8 encoded string
- Bug fix: External fonts now work like built-in fonts #17
- Bug fix: Reset colours changed by attributed text
- Bug fix: Fix global options for text_at/4 when using a string #11

## 0.3.5 (2020-04-14)

- Deprecate: `Pdf.delete/1` in favour of `Pdf.cleanup/1`
- Deprecate: `Pdf.open/2` in favour of `Pdf.build/2`
