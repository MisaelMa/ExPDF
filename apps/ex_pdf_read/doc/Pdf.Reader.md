# `Pdf.Reader`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader.ex#L1)

Native PDF reader — opens a PDF binary or file path and provides pure-functional
access to text runs with positions, raster images, document metadata, interactive
form fields, document outlines (bookmarks), and page annotations.
No GenServer, no mutable state; the reader is a fully lazy, immutable pipeline.

## Typical usage

    {:ok, doc}                          = Pdf.Reader.open("report.pdf")
    {:ok, [page1_text | _], doc}        = Pdf.Reader.read_text(doc)
    {:ok, runs, doc}                    = Pdf.Reader.read_text_with_positions(doc)
    {:ok, meta, doc}                    = Pdf.Reader.read_metadata(doc)
    {:ok, n}                            = Pdf.Reader.page_count(doc)
    :ok                                 = Pdf.Reader.close(doc)

## Outlines (bookmarks)

    {:ok, outlines, _doc} = Pdf.Reader.read_outlines(doc)
    # => [%Pdf.Reader.Outline{title: "Chapter 1", level: 0, dest_page: 1, children: [...]}, ...]

    # Bang variant — raises Pdf.Reader.Error on failure
    outlines = Pdf.Reader.read_outlines!(doc)

## Annotations

    {:ok, annotations, _doc} = Pdf.Reader.read_annotations(doc)
    # => [%Pdf.Reader.Annotation{type: :highlight, page: 2, rect: {x1, y1, x2, y2}, ...}, ...]

    # Bang variant — raises Pdf.Reader.Error on failure
    annotations = Pdf.Reader.read_annotations!(doc)

## Error recovery

`open/2` accepts a `recover: true` option that activates four orthogonal
recovery phases (R-1..R-4). Each recovery action is logged as a structured
event tuple appended to `doc.recovery_log`. Use `recovery_log/1` to inspect:

    {:ok, doc} = Pdf.Reader.open(bin, recover: true)
    Pdf.Reader.recovery_log(doc)
    # => [] when the PDF was well-formed
    # => [{:xref_recovered, 5}, {:page_failed, 2, :unresolved_ref}] on a corrupt PDF

**Closed set of recovery event tuples:**

| Tuple | Meaning |
|---|---|
| `{:xref_recovered, n}` | Linear scan recovered `n` object entries (R-3) |
| `{:eof_marker_missing, :linear_scan_used}` | `%%EOF` absent; linear scan used (R-3) |
| `{:page_failed, page_n, reason}` | Page skipped; text/images from other pages returned (R-1) |
| `{:font_skipped, page_n, font_name, reason}` | Font replaced with U+FFFD fallback (R-2) |
| `{:page_tree_recovered, n_pages}` | Catalog/Pages fallback; `n_pages` recovered (R-4) |

An empty `recovery_log` after `open/2` **guarantees** no recovery occurred.
No other tuple shapes are appended by the recovery paths.

The following errors remain fatal even with `recover: true`:
`:not_a_pdf`, `:encrypted_password_required`, `:encrypted_wrong_password`,
`:encrypted_unsupported_handler`, `{:io_error, reason}`.

**Known gaps (documented limitations):**

- **Encrypted AND corrupted PDFs** — the synthetic trailer from R-3 does not
  include `/Encrypt`; decryption cannot proceed.
- **Catalog-fallback page order (R-4)** — the page list is in xref-insertion
  order, NOT document order. `{:page_tree_recovered, n}` signals this.
- **R-4 probe cost** — `recover: true` triggers a full page-tree walk at
  `open/2` time (O(pages)). Acceptable for opt-in mode; document in callers
  that open very large PDFs.

## Encryption (Phase 2)

Standard Security Handler V1/V2/V4/V5-R6 supported. Use `open/2` with the
`password:` opt:

    {:ok, doc} = Pdf.Reader.open(bin, password: "secret")

Empty password is auto-tried first (covers metadata-protection cases).
Errors: `:encrypted_password_required`, `:encrypted_wrong_password`,
`:encrypted_unsupported_handler`. See `Pdf.Reader.Errors` for the full set.

## Form XObject recursion (Phase 3)

`Do` operators referencing `/Type /XObject /Subtype /Form` objects are
recursed into transparently — text and images inside Forms (headers,
footers, repeated logos, templated form fields) appear in `read_text*`
and `read_images/1` output. CTM is multiplied with the Form's `/Matrix`
and resources are merged (Form wins on key collision). Cycle detection
via a visited-set guards against `A → B → A` loops; recursion depth is
capped at 8 (`{:cycle_detected, ref}` and `{:max_depth_exceeded, ref}`
events are emitted internally and dropped from text output).

## Known limitations

- **No CID fonts beyond ToUnicode** — CID-keyed fonts that rely on `/CIDToGIDMap`
  or registry/ordering/supplement data are not decoded. Only `bfchar`/`bfrange`
  sections of ToUnicode CMaps are parsed.
- **No CCITT / JBIG2 / JPEG2000 image filters** — images using `CCITTFaxDecode`,
  `JBIG2Decode`, or `JPXDecode` produce `{:error, {:unsupported_filter, name}}`.
- **No OCR** — scanned PDFs with no embedded text produce an empty text list.
- **Standard-14 font metrics** — fonts without embedded `/Widths` (Standard-14
  such as Helvetica, Times-Roman) produce zero-width glyph advance; only `Tc`/`Tw`
  character/word spacing contribute. Hardcoded AFM metrics are a separate change.
- **No BBox clipping** — text outside a Form's `/BBox` is still extracted.
- **Annotation appearance streams not rendered** — visual rendering is out of scope.
- **Markup popup hierarchies not resolved** — popup windows are not extracted.
- **Sound/movie/screen/redact/3D annotations** — not extracted; surface as `:unknown`.
- **AcroForm widget annotations** — covered by `read_acroform/1`, not `read_annotations/1`.

## Spec references

- PDF 1.7 § 7.7.3 — Page Tree
- PDF 1.7 § 7.7.3.4 — Inheritance of Page Attributes (resource walk, cycle guard):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 12.3.2 — Destinations
- PDF 1.7 § 12.3.3 — Document Outline
- PDF 1.7 § 12.5 — Annotations
- PDF 1.7 § 12.5.6.x — Annotation subtypes
- PDF 1.7 § 12.6 — Actions
- PDF 1.7 § 14.3.2 — Metadata Streams (XMP merge precedence):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

## Error reasons

See `Pdf.Reader.Errors` for the complete documented reason set.

# `reason`

```elixir
@type reason() ::
  :not_a_pdf
  | :malformed
  | :encrypted_password_required
  | :encrypted_wrong_password
  | :encrypted_unsupported_handler
  | :io_error
  | {:io_error, File.posix()}
  | {:unsupported_filter, atom()}
  | {:unresolved_ref, Pdf.Reader.Document.ref()}
  | {:unsupported_pdf_version, String.t()}
  | {:malformed, atom(), map()}
```

# `attach_shapes_to_tokens`

```elixir
@spec attach_shapes_to_tokens([Pdf.Reader.Line.t()], [Pdf.Reader.Shape.t()]) :: [
  Pdf.Reader.Line.t()
]
```

Pure helper: enriches each token in a `Line` list with `:kind` and
`:shape`. Tokens without an overlapping shape get `kind: :text` and
`shape: nil`. Tokens overlapping a shape get the shape attached and
`:kind` derived from `shape.type`:

- `:uri | :goto | :launch | :named` → `:link`
- `:email` → `:email`

A shape "contains" a token when:
- The shape and the line are on the same page.
- The shape's X range overlaps the token's X range.
- The shape's Y is within ±2 points of the line's Y.

Spec references:
- PDF 1.7 § 12.5.6.5 — Link Annotations (rect semantics)
- PDF 1.7 § 12.6.4   — Action types (URI/GoTo/Launch/Named)

# `close`

```elixir
@spec close(Pdf.Reader.Document.t()) :: :ok
```

No-op in Phase 1 (no file handle or process held after `open/1`).

Exists to reserve the API slot for future streaming/mmap support and to
signal to callers that they may drop the `:binary` field to reclaim memory.

Always returns `:ok`. Does NOT raise.

# `lines_from_runs`

```elixir
@spec lines_from_runs(
  [Pdf.Reader.TextRun.t()],
  keyword()
) :: [Pdf.Reader.Line.t()]
```

Pure helper: groups a flat `TextRun` list into `Line` structs.

Exposed publicly so callers who already have a runs list (from
`read_text_with_positions/1` or hand-crafted in tests) can reuse the
grouping logic without reopening the document.

See `read_lines/2` for option semantics.

# `open`

```elixir
@spec open(
  binary() | Path.t(),
  keyword()
) :: {:ok, Pdf.Reader.Document.t()} | {:error, reason()}
```

Opens a PDF from a binary or a file path.

## Options

- `password: String.t()` — the password to use when opening an encrypted PDF.
  Defaults to `""` (the empty string). The empty password is ALWAYS tried first
  regardless of this option (R-ENC4). If the empty password succeeds, the PDF is
  opened without requiring a non-empty password.

## Success

Returns `{:ok, %Pdf.Reader.Document{}}` with:
- `:version` — the PDF version string (e.g. `"1.7"`)
- `:xref` — merged cross-reference table (all `/Prev` chains followed)
- `:trailer` — the most-recent trailer dictionary as a plain map
- `:binary` — the full PDF binary (held for lazy object resolution)
- `:cache` — starts as `%{}`
- `:encryption` — `nil` for non-encrypted PDFs; populated `%StandardHandler{}` on success

## Errors

- `{:error, :not_a_pdf}` — binary does not start with `%PDF-`
- `{:error, :malformed}` — missing `%%EOF`, invalid `startxref`, etc.
- `{:error, :encrypted_password_required}` — `/Encrypt` found; no password supplied or empty password rejected.
- `{:error, :encrypted_wrong_password}` — password supplied but authentication failed.
- `{:error, :encrypted_unsupported_handler}` — unsupported encryption handler or RC4 unavailable.
- `{:error, :io_error}` — file read failed (no detail)
- `{:error, {:io_error, posix}}` — file read failed with POSIX reason

## Spec references

- PDF 1.7 § 7.6 — Standard Security Handler:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 2.0 § 7.6 — Standard Security Handler (V5/R6):
  https://www.pdfa.org/wp-content/uploads/2023/04/ISO_32000_2_2020_PDF_2.0_FDIS.pdf

# `open!`

```elixir
@spec open!(
  binary() | Path.t(),
  keyword()
) :: Pdf.Reader.Document.t()
```

Bang variant of `open/2`. Raises `Pdf.Reader.Error` on failure.

# `page_count`

```elixir
@spec page_count(Pdf.Reader.Document.t()) :: {:ok, pos_integer()} | {:error, reason()}
```

Returns the total number of pages in the document.

Cross-validates the `/Count` entry in the page tree root against the
actual number of leaf page refs found by traversal. If they disagree,
returns `{:error, {:malformed, :page_tree_count_mismatch, %{declared: n, actual: m}}}`.

## Recovery mode (R-4)

When `recover_mode: true` and the page list was recovered via the catalog
fallback (xref scan), there is no `/Pages /Count` to cross-validate against.
In that case, the declared-count lookup is skipped and the actual count from
the xref scan is returned directly. This branch is signalled by
`{:page_tree_recovered, n}` in `recovery_log`.

Spec references: PDF 1.7 § 7.7.3 (Page Tree), § 7.7.3.4 (Inheritance).

# `page_count!`

```elixir
@spec page_count!(Pdf.Reader.Document.t()) :: pos_integer()
```

Bang variant of `page_count/1`. Raises `Pdf.Reader.Error` on failure.

# `read`

```elixir
@spec read(
  Pdf.Reader.Document.t(),
  keyword()
) :: {:ok, term(), Pdf.Reader.Document.t()} | {:error, reason()}
```

Unified entry point — returns the entire extracted PDF in one struct.

Default shape is `%Pdf.Reader.Result{}` carrying:

- `:meta` — document-level metadata (title, author, subject,
  creator, producer, dates, page_count, PDF version, encryption flag,
  recovery_log, plus the raw Info+XMP map). PDF 1.7 § 14.3.
- `:pages` — `[%Pdf.Reader.Result.Page{number, meta, lines}]`. Each
  page's `:lines` includes text lines AND embedded images as
  synthetic lines, sorted top-to-bottom. Each line's tokens carry
  `:kind` (`:text | :link | :email | :image`) and `:shape`.

## Convenience shapes

Pass `:shape` if you only want one slice without building the full struct:

- `:text` → `[String.t()]` (plain text per page)
- `:shapes` → `[%Pdf.Reader.Shape{}]` (links/emails/images flat)

## Line tokenisation opts

- `:y_tolerance` (default `2.0`) — PDF point tolerance to collapse
  text runs onto the same line.
- `:gap_factor` (default `1.15`) — token-split threshold as a
  multiplier on the per-line median inter-glyph gap. Forwarded to
  `read_lines/2`.

## Image opts

- `:image_bytes` (default `false`) — when `true`, image tokens carry
  the raw decoded `:bytes` in `meta` alongside the always-present
  `:data_uri`. Off by default to keep the result lightweight; turn
  on if the caller needs the binary (e.g. to write images to disk
  or run a QR decoder).

## Dictionary split

- `:dictionary` (default `nil`) — when set, runs an additional
  post-pass that splits glued lowercase tokens at boundaries where
  BOTH halves are valid dictionary words (e.g. `"iniciode"` →
  `"inicio"` + `"de"`). Accepts:
  - `:es` — bundled 10k Spanish wordlist
    (`Pdf.Reader.Wordlist.spanish/0`, MIT-licensed)
  - `%MapSet{}` — caller-supplied wordlist of lowercase strings
  - `nil` — disabled

  URLs/emails and tokens with digits or special chars are exempted.

## Spec references

- PDF 1.7 § 7.7.3      — Page Tree
- PDF 1.7 § 8.9        — Images (XObject /Subtype /Image)
- PDF 1.7 § 9.4        — Text objects
- PDF 1.7 § 12.5.6.5   — Link Annotations
- PDF 1.7 § 12.6.4     — Action types (URI, GoTo, Launch, Named)
- PDF 1.7 § 14.3       — Document Information Dictionary + XMP

# `read!`

```elixir
@spec read!(
  Pdf.Reader.Document.t(),
  keyword()
) :: term()
```

Bang variant of `read/2`. Raises `Pdf.Reader.Error` on failure.

# `read_acroform`

```elixir
@spec read_acroform(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.FormField.t()], Pdf.Reader.Document.t()}
  | {:error, reason()}
```

Extracts AcroForm interactive form fields from the document.

Walks the `/AcroForm /Fields` tree depth-first, emitting only leaf fields
as a flat list of `%Pdf.Reader.FormField{}` structs. Hierarchical names
(`/T` dot-joined from ancestor path) are resolved. `/FT` is inherited
downward from the nearest ancestor that defines it.

Returns `{:ok, [], doc}` when no `/AcroForm` is present or `/Fields` is empty.
Never returns `{:error, _}` for absent or empty AcroForms.

## Spec references

- PDF 1.7 § 12.7 (Interactive Forms)
- PDF 1.7 § 12.7.3 (Field Dictionaries)
- PDF 1.7 § 12.7.4 (Field Types)

# `read_acroform!`

```elixir
@spec read_acroform!(Pdf.Reader.Document.t()) :: [Pdf.Reader.FormField.t()]
```

Bang variant of `read_acroform/1`. Raises `Pdf.Reader.Error` on failure.

# `read_annotations`

```elixir
@spec read_annotations(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Annotation.t()], Pdf.Reader.Document.t()}
  | {:error, reason()}
```

Extracts all annotations from all pages in the document.

Enumerates every page via `Page.list_refs/1` and, for each page, resolves
its `/Annots` array. Supports 10 annotation subtypes:
`:link`, `:text`, `:highlight`, `:underline`, `:strikeout`, `:squiggly`,
`:square`, `:circle`, `:freetext`, `:file_attachment`. Other subtypes
surface as `:unknown` with raw fields preserved in `:kind_specific`.

Returns `{:ok, [], doc}` when no page has an `/Annots` array — never an error.

## Spec references

- PDF 1.7 § 12.5 — Annotations
- PDF 1.7 § 12.5.6.x — Annotation subtypes
- PDF 1.7 § 12.6 — Actions

# `read_annotations!`

```elixir
@spec read_annotations!(Pdf.Reader.Document.t()) :: [Pdf.Reader.Annotation.t()]
```

Bang variant of `read_annotations/1`. Raises `Pdf.Reader.Error` on failure.
Returns the annotations list directly on success.

# `read_images`

```elixir
@spec read_images(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Image.t()], Pdf.Reader.Document.t()} | {:error, reason()}
```

Extracts images from all pages.

For each page, resolves the XObject references from content-stream `Do`
operators and classifies them as JPEG or PNG-like based on their `/Filter`.

Returns `{:ok, [], doc}` when no images are found. The returned `doc`
carries an updated `:recovery_log` when opened with `recover: true`.

# `read_images!`

```elixir
@spec read_images!(Pdf.Reader.Document.t()) :: [Pdf.Reader.Image.t()]
```

Bang variant of `read_images/1`. Raises `Pdf.Reader.Error` on failure.

# `read_lines`

```elixir
@spec read_lines(
  Pdf.Reader.Document.t(),
  keyword()
) :: {:ok, [Pdf.Reader.Line.t()], Pdf.Reader.Document.t()} | {:error, reason()}
```

Reconstructs logical text lines from the page's `TextRun`s.

Many machine-generated PDFs (government forms, tax documents) place
glyphs individually with TJ + per-glyph kerning, producing one
`TextRun` per character. This function coalesces those runs into a
list of `Pdf.Reader.Line` structs, where each line carries:

- `:page`, `:y`, `:x` — absolute position in user space
- `:text` — the joined text with single spaces between tokens
- `:tokens` — `[%{x, text, width}]` separated by visible whitespace

The token list lets callers detect column layouts (e.g. table rows
where every line has tokens at the same X positions).

## Options

- `:y_tolerance` (default `2.0`) — runs whose Y differs by less than
  this many points collapse onto the same line. PDFs often jitter
  by fractional points within a line.
- `:gap_factor` (default `1.15`) — split into a new token when the
  horizontal gap between two consecutive runs exceeds the **median**
  inter-glyph gap on that line, multiplied by `gap_factor`. Using the
  median makes detection robust across fonts and sizes: monospace 4pt
  advances split at ~4.6pt, 6pt advances split at ~6.9pt, etc.
  Lower factor = more splits. Falls back to `font_size × gap_factor`
  when a line has fewer than two runs (no gap to measure).

Returns `{:ok, [Line.t()], doc}`. Lines are ordered by page ascending,
then by Y descending (top-to-bottom in PDF user space).

## Spec references

- PDF 1.7 § 9.4 — Text objects
- PDF 1.7 § 9.4.4 — Text-showing operators

# `read_lines!`

```elixir
@spec read_lines!(
  Pdf.Reader.Document.t(),
  keyword()
) :: [Pdf.Reader.Line.t()]
```

Bang variant of `read_lines/2`. Raises `Pdf.Reader.Error` on failure.

# `read_metadata`

```elixir
@spec read_metadata(Pdf.Reader.Document.t()) ::
  {:ok, %{required(String.t()) =&gt; String.t()}, Pdf.Reader.Document.t()}
  | {:error, reason()}
```

Extracts document metadata from the Info dictionary.

Resolves the trailer's `/Info` reference and returns its key-value pairs
as a `%{String.t() => String.t()}` map. String values are decoded from
PDF literal strings (`{:string, binary}`).

Common keys: `"Title"`, `"Author"`, `"Subject"`, `"Keywords"`,
`"Creator"`, `"Producer"`, `"CreationDate"`, `"ModDate"`.

Returns `{:ok, %{}, doc}` when no `/Info` entry is present.

## Spec reference

PDF 1.7 § 14.3.3 (Document Information Dictionary).

# `read_metadata!`

```elixir
@spec read_metadata!(Pdf.Reader.Document.t()) :: %{required(String.t()) =&gt; String.t()}
```

Bang variant of `read_metadata/1`. Raises `Pdf.Reader.Error` on failure.

# `read_outlines`

```elixir
@spec read_outlines(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Outline.t()], Pdf.Reader.Document.t()} | {:error, reason()}
```

Extracts document outline (bookmarks) from the PDF catalog's `/Outlines` tree.

Walks the `/First`/`/Next` linked list at each nesting level, threading
`/Parent` for depth. Cycle detection via `MapSet` and a depth cap of 32
prevent hangs on corrupt PDFs.

Returns `{:ok, [], doc}` when no `/Outlines` entry is present — never an error.

## Spec references

- PDF 1.7 § 12.3.3 — Document Outline
- PDF 1.7 § 12.3.2 — Destinations

# `read_outlines!`

```elixir
@spec read_outlines!(Pdf.Reader.Document.t()) :: [Pdf.Reader.Outline.t()]
```

Bang variant of `read_outlines/1`. Raises `Pdf.Reader.Error` on failure.
Returns the outlines list directly on success.

# `read_shapes`

```elixir
@spec read_shapes(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.Shape.t()], Pdf.Reader.Document.t()} | {:error, reason()}
```

Returns the actionable elements (link-like shapes) of the document.

Combines two sources:

- **Annotations** of subtype `/Link` (PDF 1.7 § 12.5.6.5) — real
  clickable regions placed by the document author. Each becomes a
  `%Pdf.Reader.Shape{source: :annotation}`.
- **Inferred shapes** — URL and email patterns appearing as plain
  text in `read_lines/2` output. Common in government forms that
  print `http://...` or `email@domain` without making them clickable.
  Each becomes `%Pdf.Reader.Shape{source: :inferred}`.

Returns `{:ok, shapes, doc}`. Shapes are sorted by `:page` ascending,
then by `:y` descending (top-to-bottom) when a rect is available.

## Spec references

- PDF 1.7 § 12.5.6.5 — Link Annotations
- PDF 1.7 § 12.6.4   — Action types (URI, GoTo, Launch, Named)
- RFC 3986 § 3        — URI Generic Syntax
- RFC 5321 § 4.1.2    — Mailbox/Domain syntax (mailto)

# `read_shapes!`

```elixir
@spec read_shapes!(Pdf.Reader.Document.t()) :: [Pdf.Reader.Shape.t()]
```

Bang variant of `read_shapes/1`. Raises `Pdf.Reader.Error` on failure.

# `read_text`

```elixir
@spec read_text(
  Pdf.Reader.Document.t(),
  keyword()
) :: {:ok, [String.t()], Pdf.Reader.Document.t()} | {:error, reason()}
```

Returns the plain text for each page as a list of strings.

Options:
- `:pages` — `[pos_integer]` to filter to specific 1-indexed page numbers.
  Default: all pages.

Returns `{:ok, page_strings, doc}` where each element is the concatenated
text for one page. The returned `doc` carries an updated `:recovery_log`
when opened with `recover: true`. Unresolved glyphs appear as `U+FFFD`
(already encoded by the encoding cascade layer).

# `read_text!`

```elixir
@spec read_text!(
  Pdf.Reader.Document.t(),
  keyword()
) :: [String.t()]
```

Bang variant of `read_text/2`. Raises `Pdf.Reader.Error` on failure.

# `read_text_with_positions`

```elixir
@spec read_text_with_positions(Pdf.Reader.Document.t()) ::
  {:ok, [Pdf.Reader.TextRun.t()], Pdf.Reader.Document.t()} | {:error, reason()}
```

Returns text runs with absolute positions for all pages.

Walks each page, decodes its content stream(s), and returns a flat list of
`%Pdf.Reader.TextRun{}` structs ordered by page then appearance in the
content stream.

Returns `{:ok, [], doc}` when no text is found. Never returns `:no_text_found`
as an error per the spec resolution (empty is valid).

The returned `doc` carries an updated `:recovery_log` when opened with
`recover: true` — callers should pass the returned doc to `recovery_log/1`
to inspect per-page failures.

Form XObjects (`Do` operator referencing `/Type /Form`) are NOT recursed —
per Phase 1 scope. A deferred marker is recorded but produces no TextRun.

# `read_text_with_positions!`

```elixir
@spec read_text_with_positions!(Pdf.Reader.Document.t()) :: [Pdf.Reader.TextRun.t()]
```

Bang variant of `read_text_with_positions/1`. Raises `Pdf.Reader.Error` on failure.

# `recovery_log`

```elixir
@spec recovery_log(Pdf.Reader.Document.t()) :: [Pdf.Reader.Document.recovery_event()]
```

Returns the recovery event log for a document in chronological (oldest-first) order.

An empty list guarantees that no recovery action occurred during `open/2`.
This is the canonical way for callers to inspect recovery events — direct
access to `doc.recovery_log` MUST NOT be used in application code.

The closed set of recovery event tuples is documented in `Pdf.Reader.Document`.

## Spec reference

PDF 1.7 § 7.5 — PDF file structure (recovery model).

# `shapes_from_lines`

```elixir
@spec shapes_from_lines([Pdf.Reader.Line.t()]) :: [Pdf.Reader.Shape.t()]
```

Pure helper: scans a list of `Line` structs for URL and email patterns
and emits the inferred shapes. Exposed for callers that already have
a lines list and want the inference layer alone (no annotations).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
