# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.1 — 2026-05-07 (fork: ExPDF)

First release of `ex_pdf` on Hex. Fork of
[`andrewtimberlake/elixir-pdf`](https://github.com/andrewtimberlake/elixir-pdf)
v0.7.2 (Hex package `:pdf`, ©Andrew Timberlake, MIT). The writer API is
preserved unchanged; this release adds a native PDF reader, error
recovery, AcroForm/outlines/annotations extraction, encryption support,
and many quality-of-life improvements.

### Renamed

- OTP app and Hex package: `:pdf` → `:ex_pdf`. Module names are
  unchanged (`Pdf`, `Pdf.Reader`, etc. — the namespace `Pdf.*` was kept
  to avoid breaking writer callers).
- Mixfile module: `Pdf.Mixfile` → `ExPdf.Mixfile`.
- Repo: `andrewtimberlake/elixir-pdf` → `MisaelMa/ExPDF`.
- All internal `:code.priv_dir(:pdf)` and `Application.compile_env(:pdf, …)`
  references updated to `:ex_pdf` (transparent to library users).

### Added — Native PDF reader

The reader is implemented in pure Elixir + Erlang/OTP stdlib (`:zlib`,
`:crypto`, `:binary`, `:unicode`, `:xmerl`). No new Hex runtime deps,
no system tool deps.

#### Unified entry point

- **`Pdf.Reader.read/2`** — one call returns `%Pdf.Reader.Result{meta,
  pages}` carrying document-level metadata + per-page lines with
  `:kind`-tagged tokens (`:text | :link | :email | :image`). See
  `Pdf.Reader.Result` and `Pdf.Reader.Line` for the full shape.
- Convenience shapes: `read(doc, shape: :text)` returns `[String.t()]`,
  `read(doc, shape: :shapes)` returns `[%Pdf.Reader.Shape{}]`.
- Image opt: `image_bytes: true` includes raw decoded `:bytes` in
  shape meta (off by default — `:data_uri` is always present).

#### Core extraction primitives

- `Pdf.Reader.open/2` (with optional `password:` and `recover:` opts)
- `Pdf.Reader.read_text/1` — plain text per page
- `Pdf.Reader.read_text_with_positions/1` — text runs with absolute X/Y
- `Pdf.Reader.read_lines/2` — logical lines with token tokenisation
- `Pdf.Reader.read_metadata/1` — Info dict + XMP (PDF 1.7 § 14.3)
- `Pdf.Reader.read_images/1` — embedded raster images with positions
- `Pdf.Reader.read_outlines/1` — bookmark tree
- `Pdf.Reader.read_annotations/1` — per-page annotations
- `Pdf.Reader.read_acroform/1` — interactive form fields
- `Pdf.Reader.read_shapes/1` — link-like elements (annotations + inferred)
- `Pdf.Reader.recovery_log/1` — recovery event accessor
- `Pdf.Reader.page_count/1`
- Bang variants for every read function

#### Encryption (PDF 1.7 § 7.6, PDF 2.0 § 7.6)

- Standard Security Handler V1/V2 (RC4-40, RC4-128)
- V4 with /AESV2 (AES-128) — `crypto:crypto_init_dyn/4`
- V5/R6 with /AESV3 (AES-256) — full Algorithm 2.A round trip
- Empty-password auto-try, file-key derivation per Algorithms 2/3/5/6/8

#### CID fonts (PDF 1.7 § 9.7)

- Identity-H/V composite fonts via 2-byte CID tokenisation
- 40 predefined CMaps from `adobe-type-tools/cmap-resources` bundled in
  `priv/cmap/` (UniJIS, GBK, KSC, ETen, Identity, …)
- Adobe Japan1/CNS1/Korea1/GB1 collections bundled in `priv/`
- PostScript-subset CMap parser with codespace-aware variable-length
  tokenizer
- ToUnicode CMap fallback for glyphs outside predefined ranges

#### Per-glyph widths (PDF 1.7 § 9.4.4, § 9.6.2.1, § 9.7.4.3)

- Full advance formula `tx = ((w/1000 - Tj_kern) × Tfs + Tc + Tw_space) × Th`
  applied per glyph
- Heterogeneous CIDFont `/W` parsing (Form A + Form B + interleaved)
- Standard 14 fallback to 500-unit average glyph width when `/Widths`
  is absent — restores correct positional advance for Helvetica /
  Times-Roman / Courier PDFs

#### Form XObject recursion (PDF 1.7 § 8.10)

- `Do` operator transparent recursion into `/Subtype /Form` XObjects
- CTM × Form `/Matrix` multiplication, resource merging, cycle
  detection, depth cap (8)

#### AcroForm field extraction (PDF 1.7 § 12.7)

- `Pdf.Reader.FormField` struct with `/FT` inheritance walk
- Text, button, choice, signature field types

#### Outlines and annotations (PDF 1.7 § 12.3, § 12.5)

- `Pdf.Reader.Outline` tree with destinations resolved
- `Pdf.Reader.Annotation` struct with subtype detection (link, text,
  highlight, file attachment, …)
- Annotation-source links automatically merge into the unified
  `Pdf.Reader.Shape` API

#### Image extraction (PDF 1.7 § 8.9)

- `/Subtype /Image` XObjects with absolute positions and CTM-derived
  rendered dimensions
- `:jpeg` (DCTDecode passthrough) and `:png_like` (FlateDecode +
  Predictor) classification
- **`shape.meta.data_uri`** — RFC 2397 `data:` URI ready for HTML
  embedding. JPEG is passthrough; png_like is re-encoded into a real
  PNG (PNG 1.2 § 5: signature + IHDR + IDAT + IEND with filter byte
  0 + zlib) so the URI is browser-loadable.

#### Shape inference

- `Pdf.Reader.Shape` struct unifies link annotations and pattern-
  inferred URIs/emails/images.
- URL regex per RFC 3986 § 3, email regex per RFC 5321 § 4.1.2.
- Trailing punctuation (`. , ; : ) ]`) stripped from inferred URIs.

#### Error recovery

- Opt-in `recover: true` flag with four orthogonal phases:
  - **R-1** Per-page isolation — one bad page does not kill the doc
  - **R-2** Font lenience — bad font refs fall back to U+FFFD per byte
  - **R-3** XRef linear scan — `:binary.matches/2` recovers from
    corrupted xref tables; trailer synthesis from last `trailer<<…>>`
    block or `/Type /Catalog` scan; multi-gen dedup (highest gen wins)
  - **R-4** Catalog/Pages tree fallback — `/Type /Page` xref scan when
    `/Root` or `/Pages` doesn't resolve
- Closed set of recovery event tuples observable via `recovery_log/1`:
  `:eof_marker_missing`, `:xref_recovered`, `:page_tree_recovered`,
  `:page_failed`, `:font_skipped`.
- Fatal errors (`:not_a_pdf`, `:encrypted_password_required`,
  `:encrypted_wrong_password`, `:encrypted_unsupported_handler`)
  remain hard errors even under `recover: true`.

### Added — Tooling

- **`releaser` ~> 0.0.7** dev dependency for monorepo-aware version
  bumping, changelog generation, and Hex publishing.
- Hex package metadata: maintainers, contributors (Andrew Timberlake +
  Misael Sánchez), licenses, links (GitHub + upstream + changelog).
- ExDoc `groups_for_modules` separating Reader and Writer namespaces.
- Comprehensive README documenting every reader feature with spec
  citations.

### Test suite

1180 tests, 0 failures, 30 excluded as of this release.

---

## Unreleased — pdf-reader-error-recovery

### Added

- **`Pdf.Reader.open/2` `recover: true` option** — opts in to error-recovery mode.
  When `recover: false` (the default, unchanged), all existing strict behavior is
  preserved. When `recover: true`, the reader activates four orthogonal recovery
  phases (R-1..R-4) and logs each recovery action instead of returning
  `{:error, _}`.

- **`Pdf.Reader.recovery_log/1`** — public accessor returning the recovery event
  log in chronological (oldest-first) order. An empty list after `open/2`
  guarantees that no recovery action occurred. Direct access to
  `doc.recovery_log` is discouraged in application code.

- **`Pdf.Reader.Document` struct extension** — two new fields with defaults that
  are invisible to code that does not reference them:
  - `recover_mode :: boolean()`, default `false`
  - `recovery_log :: [recovery_event()]`, default `[]`

- **PUBLIC API CHANGE — `read_text/1` and `read_images/1` return shape**.
  Both functions now return `{:ok, list, doc}` 3-tuples (doc is the updated
  document carrying the recovery log). The bang variants (`read_text!/2`,
  `read_images!/1`) are unchanged.

- **R-1 — Per-page isolation**: when `recover: true`, a failed page is logged
  as `{:page_failed, page_n, reason}` and skipped; remaining pages continue.
  Spec: PDF 1.7 § 7.7.3, § 7.8.

- **R-2 — Font decoder lenience**: when `recover: true` and a font dict fails to
  resolve, the decoder for that font is replaced with a per-byte U+FFFD identity
  decoder (`<<0xFFFD::utf8>>` per byte). The event `{:font_skipped, page_n,
  font_name, reason}` is logged. `String.valid?/1` is guaranteed true on
  recovery output. Spec: PDF 1.7 § 9.6, § 9.10.

- **R-3 — XRef linear scan**: when `recover: true` and normal xref loading fails
  (corrupt `startxref` offset, absent `%%EOF`), `XRef.recover/1` performs a
  `:binary.matches/2` scan to reconstruct the cross-reference table. A
  `{:xref_recovered, n_objects}` event is logged. When `%%EOF` is absent, an
  additional `{:eof_marker_missing, :linear_scan_used}` event is prepended.
  Spec: PDF 1.7 § 7.5.4, § 7.5.5, § 7.5.8.

- **R-4 — Catalog / Pages tree fallback**: when `recover: true` and `/Root` or
  `/Pages` cannot be resolved, the reader scans the recovered xref entries for
  objects with `/Type /Page` and (`/Contents` OR `/Parent`). A
  `{:page_tree_recovered, n_pages}` event is logged. Form XObjects (which also
  carry `/Type /Page` sometimes) are correctly excluded by the filter.
  Spec: PDF 1.7 § 7.7.2, § 7.7.3.

### Closed set of recovery event tuples

| Tuple | Meaning |
|---|---|
| `{:xref_recovered, n}` | Linear scan recovered `n` object entries |
| `{:eof_marker_missing, :linear_scan_used}` | `%%EOF` absent; linear scan was invoked |
| `{:page_failed, page_n, reason}` | Page `page_n` skipped; `reason` is an atom or term |
| `{:font_skipped, page_n, font_name, reason}` | Font replaced with U+FFFD fallback |
| `{:page_tree_recovered, n_pages}` | Catalog/Pages fallback found `n_pages` page objects |

No other tuple shapes are appended.

### Known gaps (recovery)

- **Encrypted AND corrupted PDFs** — when a PDF is both encrypted and has a
  corrupt xref/catalog, the synthetic trailer built by the linear scan does not
  include `/Encrypt`. Decryption cannot proceed; these PDFs are non-decryptable
  even with `recover: true`.
- **Catalog-fallback page order** — when R-4 triggers, the page list is in
  xref-insertion order, NOT document order. The `{:page_tree_recovered, n}`
  event signals this known limitation to callers.
- **R-4 probe cost** — with `recover: true`, `do_open/2` runs a full page-tree
  walk immediately after xref load (to surface `{:page_tree_recovered, n}` on
  the doc returned from `open/2`). This is O(pages) and measurable on large
  documents. It is opt-in by design.

### Internal

- Test suite: 1128 tests, 0 failures, 29 excluded (was 1125 before this change).
- New test file: `test/pdf/reader/recovery_test.exs` (65 tests: 16 RED, 11 GREEN,
  integration, smoke, and stress).
- Strict TDD throughout (red → green → refactor per task).
- Spec-driven via SDD (`sdd/pdf-reader-error-recovery/*` artifacts in engram).

---

## Unreleased — pdf-reader-per-glyph-widths

### Added

- **Per-glyph width support** (`Pdf.Reader.Font.Widths`): text-matrix advance
  now uses the full PDF 1.7 § 9.4.4 formula — `tx = ((w/1000) * Tfs + Tc + Tw_if_space) * Th` —
  rather than a uniform 1-em approximation. Glyph widths are loaded from:
  - `/Widths`, `/FirstChar`, `/LastChar` for simple fonts (Type1, TrueType) — § 9.6.2.1
  - `/W` Form A/B arrays and `/DW` fallback for CIDFonts (Type0) — § 9.7.4.3
- `Pdf.Reader.Font.Widths` — new module with closures of type
  `(binary() -> [non_neg_integer()])`, one per font, built alongside the existing
  decoder map in `extract_page_runs/3` and threaded through Form XObject recursion.
- `GraphicsState.widths_fn` — new field (default `nil`) storing the active font's
  width closure. Set by the `Tf` operator alongside `decoder`. (§ 9.4.4)
- `Tc`, `Tw`, `Tz`, `TL` text-state operators now correctly update `GraphicsState`.
  Previously their operands were silently dropped.
- TJ kerning shift now applies horizontal scaling (`Th`):
  `shift = -(n/1000) * Tfs * Th` (previously `Th` was omitted).

### Changed

- `GraphicsState.horizontal_scaling` default changed from `1.0` to `100.0`
  (the PDF spec unit is a percentage; `Th = horizontal_scaling / 100`).
  Existing code that reads this field directly and expects the percentage
  form is unaffected; callers that divided by 100 already will need to adjust.

### Documented gaps (not in scope)

- Vertical writing widths (`/W2`, `/DW2`) — § 9.7.4.4
- Standard-14 hardcoded AFM metrics — § 9.6.2.2 (fonts without embedded `/Widths`
  currently produce zero-width advance; Tc/Tw still apply correctly)
- Non-default `/FontMatrix` scaling on CIDType2 fonts — § 9.7.4.3

### Internal

- Test suite: 1107 tests, 0 failures, 27 excluded (was 1095 before this change).
- New file: `lib/pdf/reader/font/widths.ex`
- New test file: `test/pdf/reader/font/widths_test.exs` (25 tests)

## Unreleased — housekeeping-dialyzer-warnings

### Internal

- Removed 9 dead-code clauses flagged by Dialyzer "pattern can never match the type".
  All defensive `{:error, _}` arms in bang-wrappers and downstream pattern dispatches
  where the upstream success_typing was `{:ok, ...}`-only. No behavior change.
  Specifically: `read_metadata!/1` error branch; `extract_doc_id/1` `{:hex_string, _}`
  and `{:string, _}` patterns; `resolve_page_resources/4` dead `{n,g}` and `nil` key
  branches plus unreachable `{:error, _}` cache arm; `do_resolve_page_resources/4`
  dead `{n,g}` and `nil` parent_key branches; `font.ex` `{:error, _}` arm for
  `CID.Decoder.build/2`; `decoder.ex` `parse_registry(nil)` clause.
  Defensive `_error` / `_` fallbacks in `outlines.ex` and `annotations.ex` that guard
  against future widening of `Destination.resolve/3` return type were intentionally
  kept and annotated with comments.

## Unreleased — pdf-reader-cid-fonts-tier3

### Added

- 10 Tier 3 predefined CMaps bundled in `priv/cmap/`:
  - Adobe-Japan1: `EUC-H`, `EUC-V`
  - Adobe-CNS1: `B5-H`, `B5-V`, `ETenms-B5-H`, `ETenms-B5-V`
  - Adobe-GB1: `GB-H`, `GB-V`
  - Adobe-Korea1: `KSCms-UHC-HW-H`, `KSCms-UHC-HW-V`
  - Source: `adobe-type-tools/cmap-resources` (Apache-2.0)
- `Pdf.Reader.CID.PredefinedCMap.@bundled` set extended from 30 to 40 names.

### Internal

- Test suite: 1063 tests, 3 pre-existing failures (encryption), 0 new failures.
- Bundle size: +51.9 KB additional `priv/cmap/` data.

## Unreleased — housekeeping-mix-format

### Internal

- Auto-formatted 12 pre-existing files via `mix format` to satisfy `--check-formatted`.
  Affected files: `lib/pdf.ex`, `lib/pdf/builder.ex`, `lib/pdf/fonts.ex`, `lib/pdf/images/png.ex`,
  `lib/pdf/layout.ex`, `lib/pdf/page.ex`, `lib/pdf/styled_table.ex`,
  `test/pdf/builder_test.exs`, `test/pdf/fonts_test.exs`, `test/pdf/layout_test.exs`,
  `test/pdf/page_templates_test.exs`, `test/pdf/styled_table_test.exs`. No behavior change.

## Unreleased — pdf-reader-annotations-outlines

### Added

- **Document outlines (bookmarks)** — `Pdf.Reader.read_outlines/1` returns
  `[%Pdf.Reader.Outline{title, level, dest_page, children}]` walking
  catalog `/Outlines` linked list with cycle detection (visited MapSet)
  and depth cap 32.
- **Annotations** — `Pdf.Reader.read_annotations/1` returns
  `[%Pdf.Reader.Annotation{type, page, rect, contents, ...}]` for the
  10 in-scope subtypes: Link, Text, Highlight, Underline, StrikeOut,
  Squiggly, Square, Circle, FreeText, FileAttachment. Other subtypes
  surface as `:type :unknown` with raw fields preserved in
  `:kind_specific`.
- **`Pdf.Reader.Destination`** — resolves all 4 `/Dest` variants
  (direct array, named string, `/A /S /GoTo /D <array>`, `/A /S /GoTo /D <name>`).
  Name-tree walker handles depth-20 + cycle detection.
- **`Pdf.Reader.Utils`** — extracted shared `decode_pdf_string/1` (UTF-16BE BOM
  + hex string aware) and `parse_rect/1`. `Pdf.Reader` and
  `Pdf.Reader.AcroForm` migrated to use Utils; private duplicates removed.
- **Page index cache** — `:page_ref_index` cached once per `read_*` call
  via `Destination.ensure_page_index/1`. Avoids O(n) page-ref lookups
  per annotation/outline.

### Out of scope
- Annotation appearance streams.
- Markup popup hierarchies.
- Sound/movie/screen/redact/3D annotations.
- AcroForm widget annotations (covered by separate `pdf-reader-acroform-extraction`).

### Internal
- 1053+ tests, 0 failures.
- Strict TDD throughout.
- Spec-driven via SDD (`sdd/pdf-reader-annotations-outlines/*` artifacts in engram).

---

## Unreleased — pdf-reader-cid-fonts-cmap-resources

### Added

- **30 Adobe predefined CMaps bundled in `priv/cmap/`** (Tier 1 + Tier 2):
  - Tier 1 (16 files): `UniJIS-UTF16-H/V`, `UniJIS-UCS2-H/V`, `UniCNS-UTF16-H/V`,
    `UniCNS-UCS2-H/V`, `UniGB-UTF16-H/V`, `UniGB-UCS2-H/V`, `UniKS-UTF16-H/V`,
    `UniKS-UCS2-H/V`
  - Tier 2 (14 files): `GBK-EUC-H/V`, `GBKp-EUC-H/V`, `GBK2K-H/V`, `ETen-B5-H/V`,
    `KSCms-UHC-H/V`, `90ms-RKSJ-H/V`, `90msp-RKSJ-H/V`
  - Source: `adobe-type-tools/cmap-resources` (Apache-2.0)

- **`Pdf.Reader.CID.CMapParser`** — minimal PostScript subset parser
  (`codespacerange`, `cidchar`, `cidrange`, `notdefchar`, `notdefrange`, `usecmap`).
  Silently skips all other PS content. Returns `{:ok, cmap_fields} | {:error, reason}`.
  Never raises on malformed input.

- **`Pdf.Reader.CID.Codespace.tokenize/2`** — variable-length 1–4 byte
  codespace-aware tokenizer per PDF 1.7 § 9.7.6 shortest-match rule.
  Bytes outside all codespace ranges are silently dropped one-at-a-time.

- **`Pdf.Reader.CID.PredefinedCMap`** — lazy loader with `Document.cache`
  keyed `{:predefined_cmap, name}` and `usecmap` chain support (cycle
  detection via visited MapSet; missing/non-bundled parents fall back to
  empty CMap per discovery #182).

- **`Pdf.Reader.CID.Decoder.build_predefined/2`** — new dispatch branch
  resolves bytes → CID via codespace + CMap → Unicode via existing Adobe
  collection table. Resolution cascade: ToUnicode CMap → predefined CMap
  → Adobe registry → U+FFFD with sentinel.

- **`Pdf.Reader.Font.cid_font_type/1`** — extends the former `cid_font?/1`
  predicate to recognise bundled predefined CMap names; dispatch returns
  `:identity | {:predefined, name} | :not_cid`.

### Known Limitations

- **Tier 3 CMaps not bundled** — `EUC`, `B5`, `GB`, `ETenms-B5`, `KSCms-UHC-HW`
  and similar encodings were deferred. Shipped in `pdf-reader-cid-fonts-tier3`.
- **Adobe-{Japan1,CNS1,Korea1,GB1}-UCS2 abstract parent files do not exist**
  in `adobe-type-tools/cmap-resources`. The `usecmap` operator falls back to
  empty parent CMap if the named parent is not bundled — child's mappings still
  work standalone. Real-world `usecmap` chains are exercised via -V → -H pairs
  (e.g. `UniJIS-UTF16-V usecmap UniJIS-UTF16-H`).

### Internal

- Test suite: 909 tests, 0 failures (was 890 before this change's tests).
- Strict TDD throughout (red → green → refactor per task pair).
- Spec-driven via SDD (`sdd/pdf-reader-cid-fonts-cmap-resources/*`).

---

## Unreleased — pdf-reader-cid-fonts

### Added

- **CID composite font support** — Type0 fonts with `/Encoding /Identity-H` or
  `/Identity-V` are now dispatched to a new CID decoder path in
  `Pdf.Reader.Font.build_decoder_internal/2`. Text extraction from standard
  CJK PDFs (Japanese, Chinese Traditional/Simplified, Korean) now returns
  correct Unicode instead of `U+FFFD`.

- **Four Adobe collection modules** — compile-time CID → Unicode tables bundled
  as `@external_resource` pattern-match clauses (O(1) BEAM dispatch):
  - `Pdf.Reader.CID.AdobeJapan1` — ~9 600 entries (UniJIS-UCS2 column)
  - `Pdf.Reader.CID.AdobeCNS1` — ~18 300 entries (UniCNS-UCS2 column)
  - `Pdf.Reader.CID.AdobeKorea1` — ~17 100 entries (UniKS-UCS2 column)
  - `Pdf.Reader.CID.AdobeGB1` — ~28 700 entries (UniGB-UCS2 column)

  Source data: `adobe-type-tools/cmap-resources` repository.
  Blob SHAs committed:
  - `Adobe-Japan1-7/cid2code.txt` → `4aead36837da`
  - `Adobe-CNS1-7/cid2code.txt`   → `13ebdcb98e07`
  - `Adobe-Korea1-2/cid2code.txt` → `0b5db6b5f5c3`
  - `Adobe-GB1-6/cid2code.txt`    → `c94c7bf8c943`
  - Repository HEAD at time of normalization: `f5cf3bca7fdf`

- **`Pdf.Reader.CID.CIDToGIDMap`** — parses `/CIDToGIDMap` entries
  (`/Identity`, FlateDecode-decoded binary stream, or indirect ref). Stored for
  future glyph-rendering work; not used in the Unicode cascade.

- **`Pdf.Reader.CID.Decoder`** — resolves per-CID Unicode via cascade:
  ToUnicode CMap → Adobe registry table → `U+FFFD` with sentinel
  `{idx, "cid:0xHHHH"}`.

- **`mix.exs` `package.files`** — `"priv"` added so that `@external_resource`
  paths in the Adobe collection modules resolve correctly at Hex compile time.

### Known limitations

- **Non-Identity predefined CMaps not decoded** — fonts with
  `/Encoding /UniJIS-UTF16-H`, `/GBK-EUC-H`, etc. fall through to the
  simple-font path and emit `U+FFFD` with sentinels. Full support planned for
  future change `pdf-reader-cid-fonts-cmap-resources`.
- **Vertical writing mode** — Identity-V is dispatched to the same decoder as
  Identity-H. No positional adjustments for vertical layout.

## Unreleased — pdf-reader-acroform-extraction

### Added

- **`Pdf.Reader.read_acroform/1` and `read_acroform!/1`** — extract interactive
  AcroForm form fields from a PDF document. Returns a flat list of
  `%Pdf.Reader.FormField{}` structs with decoded names, types, values, flags,
  and rectangles. Absent `/AcroForm` returns `{:ok, [], doc}` — never an error.
- **`Pdf.Reader.FormField`** struct — carries `:name` (fully-qualified dot-path),
  `:partial_name`, `:type` (`:text | :button | :choice | :signature | :unknown`),
  `:value` (type-specific decoded value), `:default`, `:tooltip`, `:flags`
  (`%{atom => boolean}` decoded from `/Ff` bitmask), `:rect`.
- **`Pdf.Reader.AcroForm`** walker module — depth-first leaf-only walker with
  cycle detection (`MapSet` of `{n, g}` xref keys), depth cap (`@max_field_depth 8`),
  `/FT` inheritance, hierarchical naming, and widget-only annotation filtering.

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
