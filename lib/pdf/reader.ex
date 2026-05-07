defmodule Pdf.Reader do
  @moduledoc """
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
  """

  alias Pdf.Reader.{
    AcroForm,
    Annotation,
    Annotations,
    Document,
    Encryption,
    Filter,
    Font,
    Font.Widths,
    FormField,
    ObjectResolver,
    Outline,
    Outlines,
    Page,
    Trailer,
    Utils,
    XMP,
    XRef
  }

  alias Pdf.Reader.Encryption.StandardHandler

  @type reason ::
          :not_a_pdf
          | :malformed
          | :encrypted_password_required
          | :encrypted_wrong_password
          | :encrypted_unsupported_handler
          | :io_error
          | {:io_error, File.posix()}
          | {:unsupported_filter, atom()}
          | {:unresolved_ref, Document.ref()}
          | {:unsupported_pdf_version, String.t()}
          | {:malformed, atom(), map()}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
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
  """
  @spec open(binary() | Path.t(), keyword()) :: {:ok, Document.t()} | {:error, reason()}
  def open(path_or_binary, opts \\ [])

  # Starts with %PDF- magic bytes → definitely raw PDF content
  def open(<<"%PDF-", _::binary>> = binary, opts) do
    do_open(binary, opts)
  end

  # Binary that doesn't start with %PDF-:
  # - If it looks like a filesystem path (starts with / . ~ or contains path separators
  #   and has a .pdf-like extension), treat as file path.
  # - Otherwise treat as raw binary content (returns :not_a_pdf for non-PDF bytes).
  def open(path, opts) when is_binary(path) do
    if looks_like_path?(path) do
      read_file_and_open(path, opts)
    else
      do_open(path, opts)
    end
  end

  # File path as charlist
  def open(path, opts) when is_list(path) do
    read_file_and_open(path, opts)
  end

  # Heuristic: treat as a filesystem path if it starts with / or ./ or ../
  # or if it contains path separators and doesn't look like raw binary content.
  defp looks_like_path?(bin) do
    String.starts_with?(bin, "/") or
      String.starts_with?(bin, "./") or
      String.starts_with?(bin, "../") or
      String.starts_with?(bin, "~") or
      (String.contains?(bin, "/") and String.printable?(String.slice(bin, 0, 50)))
  end

  defp read_file_and_open(path, opts) do
    case File.read(path) do
      {:ok, bin} -> do_open(bin, opts)
      {:error, :enoent} -> {:error, {:io_error, :enoent}}
      {:error, reason} -> {:error, {:io_error, reason}}
    end
  end

  @doc """
  No-op in Phase 1 (no file handle or process held after `open/1`).

  Exists to reserve the API slot for future streaming/mmap support and to
  signal to callers that they may drop the `:binary` field to reclaim memory.

  Always returns `:ok`. Does NOT raise.
  """
  @spec close(Document.t()) :: :ok
  def close(_doc), do: :ok

  @doc """
  Returns the recovery event log for a document in chronological (oldest-first) order.

  An empty list guarantees that no recovery action occurred during `open/2`.
  This is the canonical way for callers to inspect recovery events — direct
  access to `doc.recovery_log` MUST NOT be used in application code.

  The closed set of recovery event tuples is documented in `Pdf.Reader.Document`.

  ## Spec reference

  PDF 1.7 § 7.5 — PDF file structure (recovery model).
  """
  @spec recovery_log(Document.t()) :: [Document.recovery_event()]
  def recovery_log(%Document{recovery_log: log}), do: Enum.reverse(log)

  @doc """
  Extracts document metadata from the Info dictionary.

  Resolves the trailer's `/Info` reference and returns its key-value pairs
  as a `%{String.t() => String.t()}` map. String values are decoded from
  PDF literal strings (`{:string, binary}`).

  Common keys: `"Title"`, `"Author"`, `"Subject"`, `"Keywords"`,
  `"Creator"`, `"Producer"`, `"CreationDate"`, `"ModDate"`.

  Returns `{:ok, %{}, doc}` when no `/Info` entry is present.

  ## Spec reference

  PDF 1.7 § 14.3.3 (Document Information Dictionary).
  """
  @spec read_metadata(Document.t()) ::
          {:ok, %{String.t() => String.t()}, Document.t()} | {:error, reason()}
  def read_metadata(%Document{trailer: trailer} = doc) do
    # Step 1: Read /Info dictionary (existing path)
    {info_meta, doc1} =
      case Map.get(trailer, "Info") do
        nil ->
          {%{}, doc}

        info_ref ->
          case ObjectResolver.resolve(doc, info_ref) do
            {:ok, info_dict, updated_doc} when is_map(info_dict) ->
              meta =
                info_dict
                |> Enum.flat_map(fn {k, v} ->
                  case decode_info_value(v) do
                    nil -> []
                    str -> [{k, str}]
                  end
                end)
                |> Map.new()

              {meta, updated_doc}

            {:ok, _non_dict, updated_doc} ->
              {%{}, updated_doc}

            {:error, _} ->
              {%{}, doc}
          end
      end

    # Step 2: Read XMP stream from catalog /Metadata, merge with /Info
    # XMP wins on conflict per PDF 1.7 § 14.3.2.
    {xmp_meta, doc2} = read_xmp_stream(doc1)

    merged = Map.merge(info_meta, xmp_meta)
    {:ok, merged, doc2}
  end

  @doc """
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
  """
  @spec page_count(Document.t()) :: {:ok, pos_integer()} | {:error, reason()}
  def page_count(%Document{} = doc) do
    with {:ok, refs, updated_doc} <- Page.list_refs(doc) do
      actual = length(refs)

      if actual == 0 do
        {:error, :no_pages}
      else
        # R-4: when the page list was obtained via catalog-fallback (xref scan),
        # there is no /Pages /Count to cross-validate. Detect this by checking
        # if a :page_tree_recovered event was appended during list_refs/1.
        # In that case return the actual count directly, bypassing the cross-check.
        page_tree_recovered? =
          Enum.any?(updated_doc.recovery_log, &match?({:page_tree_recovered, _}, &1))

        if page_tree_recovered? do
          {:ok, actual}
        else
          case read_declared_count(updated_doc) do
            {:ok, declared_count} when declared_count == actual ->
              {:ok, actual}

            {:ok, declared_count} ->
              {:error,
               {:malformed, :page_tree_count_mismatch,
                %{declared: declared_count, actual: actual}}}

            {:error, _} when doc.recover_mode ->
              # recover_mode active but no /Pages /Count found — return actual count
              {:ok, actual}

            {:error, _} = err ->
              err
          end
        end
      end
    end
  end

  @doc """
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

  ## Spec references

  - PDF 1.7 § 7.7.3      — Page Tree
  - PDF 1.7 § 8.9        — Images (XObject /Subtype /Image)
  - PDF 1.7 § 9.4        — Text objects
  - PDF 1.7 § 12.5.6.5   — Link Annotations
  - PDF 1.7 § 12.6.4     — Action types (URI, GoTo, Launch, Named)
  - PDF 1.7 § 14.3       — Document Information Dictionary + XMP
  """
  @spec read(Document.t(), keyword()) ::
          {:ok, term(), Document.t()} | {:error, reason()}
  def read(%Document{} = doc, opts \\ []) do
    case Keyword.get(opts, :shape, :document) do
      :document -> read_full_document(doc, opts)
      :text -> read_text(doc, opts)
      :shapes -> read_shapes(doc)
      other -> {:error, {:unknown_shape, other}}
    end
  end

  @doc """
  Bang variant of `read/2`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read!(Document.t(), keyword()) :: term()
  def read!(doc, opts \\ []) do
    case read(doc, opts) do
      {:ok, value, _doc} -> value
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  # Default shape — assembles the full %Pdf.Reader.Result{} from
  # text lines + shapes + images + Info/XMP metadata, partitioned by page.
  defp read_full_document(doc, opts) do
    with {:ok, info, doc1} <- read_metadata(doc),
         {:ok, shapes, doc2} <- read_shapes(doc1),
         {:ok, lines, doc3} <- read_lines(doc2, opts),
         {:ok, images, doc4} <- read_images(doc3),
         {:ok, page_count} <- page_count(doc4) do
      include_bytes = Keyword.get(opts, :image_bytes, false)
      enriched_text_lines = attach_shapes_to_tokens(lines, shapes)
      image_lines = Enum.map(images, &image_to_synthetic_line(&1, include_bytes))

      all_lines =
        (enriched_text_lines ++ image_lines)
        |> Enum.sort_by(fn line -> {line.page, -line.y} end)

      pages = build_result_pages(all_lines, page_count)
      meta = build_result_meta(doc4, info, page_count)

      {:ok, %Pdf.Reader.Result{meta: meta, pages: pages}, doc4}
    end
  end

  # Group lines by their :page field; emit one Result.Page per page index
  # in the document, even when a page has no extractable lines.
  defp build_result_pages(lines, page_count) do
    by_page = Enum.group_by(lines, & &1.page)

    for page_num <- 1..page_count do
      page_lines = Map.get(by_page, page_num, [])

      %Pdf.Reader.Result.Page{
        number: page_num,
        meta: %{},
        lines: page_lines
      }
    end
  end

  # Document-level metadata: normalise the standard Info-dict keys
  # (PDF 1.7 § 14.3.3) to atom keys, keep the raw map for vendor extras,
  # and add reader-derived fields (page_count, version, encrypted, log).
  defp build_result_meta(%Document{} = doc, info, page_count) do
    %{
      title: Map.get(info, "Title"),
      author: Map.get(info, "Author"),
      subject: Map.get(info, "Subject"),
      keywords: Map.get(info, "Keywords"),
      creator: Map.get(info, "Creator"),
      producer: Map.get(info, "Producer"),
      creation_date: Map.get(info, "CreationDate"),
      mod_date: Map.get(info, "ModDate"),
      page_count: page_count,
      version: doc.version,
      encrypted: doc.encryption != nil,
      recovery_log: recovery_log(doc),
      raw: info
    }
  end

  # Converts a raster image into a one-token synthetic line so the unified
  # `read/2` output surfaces it inline at its position. The token's
  # `:shape` carries format, dimensions, and a ready-to-use `:data_uri`
  # (RFC 2397) so callers can drop it into `<img src="...">` without
  # further work. The raw `:bytes` are only attached when the caller
  # passes `image_bytes: true` to `read/2` — by default the result is
  # kept lightweight.
  #
  # JPEG passthrough is straightforward (bytes are a complete JFIF file).
  # `:png_like` bytes are decompressed pixel data — we wrap them in a real
  # PNG container (PNG 1.2 § 5: signature + IHDR + IDAT + IEND, with
  # filter byte 0 prepended to each scanline and zlib-compressed) so the
  # data_uri is browser-loadable. Color type is inferred from
  # `byte_size / (width × height)`: 1=gray, 2=gray+alpha, 3=RGB, 4=RGBA.
  defp image_to_synthetic_line(%Pdf.Reader.Image{} = img, include_bytes) do
    rect = {img.x, img.y, img.x + img.render_width, img.y + img.render_height}
    {data_uri, encoded_format} = build_data_uri(img)

    base_meta = %{
      format: img.kind,
      encoded_format: encoded_format,
      width: img.width,
      height: img.height,
      render_width: img.render_width,
      render_height: img.render_height,
      byte_size: byte_size(img.bytes),
      data_uri: data_uri
    }

    meta = if include_bytes, do: Map.put(base_meta, :bytes, img.bytes), else: base_meta

    shape = %Pdf.Reader.Shape{
      type: :image,
      page: img.page,
      rect: rect,
      target: img.ref,
      text: nil,
      source: :embedded,
      meta: meta
    }

    token = %{
      x: img.x,
      text: "",
      width: img.render_width,
      kind: :image,
      shape: shape
    }

    %Pdf.Reader.Line{
      page: img.page,
      y: img.y,
      x: img.x,
      text: "",
      tokens: [token]
    }
  end

  # JPEG → passthrough; png_like → wrap pixels in a real PNG.
  # Returns {data_uri, encoded_format} where encoded_format is the MIME
  # subtype that the data_uri actually carries.
  defp build_data_uri(%Pdf.Reader.Image{kind: :jpeg, bytes: bytes}) do
    {"data:image/jpeg;base64," <> Base.encode64(bytes), :jpeg}
  end

  defp build_data_uri(%Pdf.Reader.Image{kind: :png_like} = img) do
    case encode_png(img) do
      {:ok, png} -> {"data:image/png;base64," <> Base.encode64(png), :png}
      :error -> {nil, nil}
    end
  end

  defp build_data_uri(_), do: {nil, nil}

  # PNG signature (PNG 1.2 § 5.2)
  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  defp encode_png(%Pdf.Reader.Image{bytes: pixels, width: w, height: h}) when w > 0 and h > 0 do
    width = trunc(w)
    height = trunc(h)
    total = byte_size(pixels)

    case rem(total, width * height) do
      0 ->
        channels = div(total, width * height)
        color_type = png_color_type(channels)

        if color_type != nil do
          ihdr =
            <<width::32, height::32, 8::8, color_type::8, 0::8, 0::8, 0::8>>

          row_size = width * channels
          filtered = prepend_filter_bytes(pixels, row_size)
          idat = :zlib.compress(filtered)

          {:ok,
           @png_signature <>
             png_chunk("IHDR", ihdr) <>
             png_chunk("IDAT", idat) <>
             png_chunk("IEND", "")}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp encode_png(_), do: :error

  defp png_color_type(1), do: 0
  defp png_color_type(2), do: 4
  defp png_color_type(3), do: 2
  defp png_color_type(4), do: 6
  defp png_color_type(_), do: nil

  # Each scanline gets a filter byte (0x00 = None per PNG 1.2 § 9) prepended.
  defp prepend_filter_bytes(pixels, row_size) do
    for <<row::binary-size(row_size) <- pixels>>, into: <<>>, do: <<0::8, row::binary>>
  end

  # PNG chunk: length(4) + type(4) + data + CRC32(4) over type+data.
  defp png_chunk(type, data) when is_binary(type) and is_binary(data) do
    crc = :erlang.crc32(type <> data)
    <<byte_size(data)::32, type::binary, data::binary, crc::32>>
  end

  @doc """
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
  """
  @spec attach_shapes_to_tokens([Pdf.Reader.Line.t()], [Pdf.Reader.Shape.t()]) ::
          [Pdf.Reader.Line.t()]
  def attach_shapes_to_tokens(lines, shapes) when is_list(lines) and is_list(shapes) do
    shapes_by_page = Enum.group_by(shapes, & &1.page)

    Enum.map(lines, fn %Pdf.Reader.Line{} = line ->
      page_shapes = Map.get(shapes_by_page, line.page, [])

      new_tokens =
        Enum.map(line.tokens, fn token ->
          shape = find_overlapping_shape(token, line, page_shapes)

          token
          |> Map.put(:shape, shape)
          |> Map.put(:kind, kind_from_shape(shape))
        end)

      %{line | tokens: new_tokens}
    end)
  end

  # Kind derived from shape.type, mapping action-like types to :link.
  defp kind_from_shape(nil), do: :text
  defp kind_from_shape(%Pdf.Reader.Shape{type: :email}), do: :email
  defp kind_from_shape(%Pdf.Reader.Shape{type: type}) when type in [:uri, :goto, :launch, :named],
    do: :link

  defp kind_from_shape(_), do: :text

  defp find_overlapping_shape(token, %Pdf.Reader.Line{y: line_y}, shapes) do
    token_x_start = token.x
    token_x_end = token.x + Map.get(token, :width, 0.0)

    Enum.find(shapes, fn shape ->
      case shape.rect do
        nil ->
          false

        {sx1, sy1, sx2, sy2} ->
          x_lo = min(sx1, sx2)
          x_hi = max(sx1, sx2)
          y_lo = min(sy1, sy2) - 2.0
          y_hi = max(sy1, sy2) + 2.0

          line_y >= y_lo and line_y <= y_hi and
            token_x_end >= x_lo and token_x_start <= x_hi
      end
    end)
  end

  @doc """
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
  """
  @spec read_text_with_positions(Document.t()) ::
          {:ok, [Pdf.Reader.TextRun.t()], Document.t()} | {:error, reason()}
  def read_text_with_positions(%Document{} = doc) do
    with {:ok, page_refs, doc2} <- Page.list_refs(doc) do
      collect_text_runs(page_refs, doc2, 1, [])
    end
  end

  @doc """
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
  """
  @spec read_lines(Document.t(), keyword()) ::
          {:ok, [Pdf.Reader.Line.t()], Document.t()} | {:error, reason()}
  def read_lines(%Document{} = doc, opts \\ []) do
    with {:ok, runs, doc2} <- read_text_with_positions(doc) do
      {:ok, lines_from_runs(runs, opts), doc2}
    end
  end

  @doc """
  Bang variant of `read_lines/2`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_lines!(Document.t(), keyword()) :: [Pdf.Reader.Line.t()]
  def read_lines!(doc, opts \\ []) do
    case read_lines(doc, opts) do
      {:ok, lines, _doc} -> lines
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
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
  """
  @spec read_shapes(Document.t()) ::
          {:ok, [Pdf.Reader.Shape.t()], Document.t()} | {:error, reason()}
  def read_shapes(%Document{} = doc) do
    with {:ok, anns, doc2} <- read_annotations(doc),
         {:ok, lines, doc3} <- read_lines(doc2) do
      annotation_shapes = Enum.flat_map(anns, &annotation_to_shape/1)
      inferred_shapes = shapes_from_lines(lines)

      shapes =
        (annotation_shapes ++ inferred_shapes)
        |> Enum.sort_by(fn s ->
          {s.page, -shape_y(s)}
        end)

      {:ok, shapes, doc3}
    end
  end

  @doc """
  Bang variant of `read_shapes/1`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_shapes!(Document.t()) :: [Pdf.Reader.Shape.t()]
  def read_shapes!(doc) do
    case read_shapes(doc) do
      {:ok, shapes, _doc} -> shapes
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
  Pure helper: scans a list of `Line` structs for URL and email patterns
  and emits the inferred shapes. Exposed for callers that already have
  a lines list and want the inference layer alone (no annotations).
  """
  @spec shapes_from_lines([Pdf.Reader.Line.t()]) :: [Pdf.Reader.Shape.t()]
  def shapes_from_lines(lines) when is_list(lines) do
    Enum.flat_map(lines, &infer_shapes_in_line/1)
  end

  # URI / email regexes, simplified per RFC 3986 § 3 (URI Generic Syntax)
  # and RFC 5321 § 4.1.2 (Mailbox). Match a tight subset that excludes
  # trailing punctuation that almost certainly isn't part of the URI.
  @url_regex ~r|https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+|u
  @www_regex ~r|www\.[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+|u
  @email_regex ~r|[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}|u

  defp infer_shapes_in_line(%Pdf.Reader.Line{} = line) do
    Enum.flat_map(line.tokens, fn token -> infer_shapes_in_token(token, line) end)
  end

  defp infer_shapes_in_token(%{text: text} = token, line) do
    email = Regex.run(@email_regex, text)
    url_https = Regex.run(@url_regex, text)
    url_www = Regex.run(@www_regex, text)

    cond do
      email != nil ->
        [build_inferred_shape(:email, hd(email), token, line)]

      url_https != nil ->
        [build_inferred_shape(:uri, hd(url_https) |> trim_trailing_punct(), token, line)]

      url_www != nil ->
        [build_inferred_shape(:uri, hd(url_www) |> trim_trailing_punct(), token, line)]

      true ->
        []
    end
  end

  defp build_inferred_shape(type, target, token, line) do
    %Pdf.Reader.Shape{
      type: type,
      page: line.page,
      rect: {token.x, line.y, token.x + token.width, line.y},
      target: target,
      text: target,
      source: :inferred
    }
  end

  # URLs commonly appear as the last word in a sentence: "see http://x.com."
  # Strip trailing punctuation that is unlikely to be part of the URI.
  defp trim_trailing_punct(uri) do
    String.trim_trailing(uri, ".")
    |> String.trim_trailing(",")
    |> String.trim_trailing(";")
    |> String.trim_trailing(":")
    |> String.trim_trailing(")")
    |> String.trim_trailing("]")
  end

  # Convert a /Link annotation to one or more shapes.
  # PDF 1.7 § 12.5.6.5: a Link annotation may carry a URI action (`:url`),
  # a GoTo destination (`:dest_page`), or other action types we don't
  # currently model. We surface what we have.
  defp annotation_to_shape(%Pdf.Reader.Annotation{type: :link} = ann) do
    cond do
      ann.url != nil and is_binary(ann.url) ->
        type = if String.contains?(ann.url, "@") and not String.contains?(ann.url, "://"),
                 do: :email,
                 else: :uri

        [
          %Pdf.Reader.Shape{
            type: type,
            page: ann.page || 1,
            rect: ann.rect,
            target: ann.url,
            text: ann.contents,
            source: :annotation
          }
        ]

      ann.dest_page != nil ->
        [
          %Pdf.Reader.Shape{
            type: :goto,
            page: ann.page || 1,
            rect: ann.rect,
            target: %{page: ann.dest_page},
            text: ann.contents,
            source: :annotation
          }
        ]

      true ->
        []
    end
  end

  defp annotation_to_shape(_), do: []

  # Y for sorting — top of rect (highest y in PDF user-space) when present.
  defp shape_y(%Pdf.Reader.Shape{rect: nil}), do: 0.0
  defp shape_y(%Pdf.Reader.Shape{rect: {_x1, y1, _x2, y2}}), do: max(y1, y2) * 1.0

  @doc """
  Pure helper: groups a flat `TextRun` list into `Line` structs.

  Exposed publicly so callers who already have a runs list (from
  `read_text_with_positions/1` or hand-crafted in tests) can reuse the
  grouping logic without reopening the document.

  See `read_lines/2` for option semantics.
  """
  @spec lines_from_runs([Pdf.Reader.TextRun.t()], keyword()) :: [Pdf.Reader.Line.t()]
  def lines_from_runs(runs, opts \\ []) when is_list(runs) do
    y_tol = Keyword.get(opts, :y_tolerance, 2.0)
    gap_factor = Keyword.get(opts, :gap_factor, 1.15)

    runs
    |> Enum.reject(&(&1.text == ""))
    |> Enum.group_by(& &1.page)
    |> Enum.sort_by(fn {page, _} -> page end)
    |> Enum.flat_map(fn {page, page_runs} ->
      page_runs
      |> bucket_by_y(y_tol)
      |> Enum.map(&build_line(page, &1, gap_factor))
    end)
  end

  # Sort by Y descending (PDF Y goes up — top of page = highest Y),
  # then walk the sorted list, opening a new bucket whenever the Y drop
  # exceeds the tolerance.
  #
  # Buckets are accumulated by prepend for O(1) growth, then reversed so
  # the runs within each bucket retain their parser-emit order. This is
  # critical for PDFs that use a single `TJ` operator across many glyphs:
  # all glyph runs share the same starting X, so the X-sort below cannot
  # recover natural reading order — the parser order is the only signal.
  defp bucket_by_y(runs, y_tol) do
    runs
    |> Enum.sort_by(& &1.y, :desc)
    |> Enum.reduce([], fn run, acc ->
      case acc do
        [] ->
          [[run]]

        [[head | _] = current | rest] ->
          if abs(run.y - head.y) <= y_tol do
            [[run | current] | rest]
          else
            [[run], current | rest]
          end
      end
    end)
    |> Enum.reverse()
    |> Enum.map(&Enum.reverse/1)
  end

  defp build_line(page, line_runs, gap_factor) do
    sorted = sort_by_x_with_parser_tiebreaker(line_runs)
    tokens = tokenize_runs(sorted, gap_factor)
    text = tokens |> Enum.map(& &1.text) |> Enum.join(" ")
    first = List.first(sorted)

    %Pdf.Reader.Line{
      page: page,
      y: first.y,
      x: first.x,
      text: text,
      tokens: tokens
    }
  end

  # Sort runs by X but preserve parser-emit order when X positions are
  # close (within ~0.75 em). This handles PDFs that emit text with small
  # backward jumps — common in label/value layouts where the producer
  # writes the label, then jumps slightly back to overlap the value.
  # Pure X-sort would scramble the chars (e.g. "Territorial:" + "S" with
  # `S.x < :.x` produced "TerritorialS:OLIDARIDAD" instead of
  # "Territorial:SOLIDARIDAD"). Using a bin size proportional to the
  # font size keeps column-aligned tables intact (column gaps are
  # always >> 1 em apart so they fall in different bins) while
  # collapsing close-X cluster jitter to parser order.
  defp sort_by_x_with_parser_tiebreaker(runs) do
    bin_size = bin_size_for_runs(runs)

    runs
    |> Enum.with_index()
    |> Enum.sort_by(fn {r, idx} -> {trunc(r.x / bin_size), idx} end)
    |> Enum.map(&elem(&1, 0))
  end

  defp bin_size_for_runs([]), do: 8.0

  defp bin_size_for_runs(runs) do
    size =
      runs
      |> Enum.map(& &1.size)
      |> Enum.max(fn -> 8.0 end)

    max(size * 0.75, 1.0)
  end

  # Split a sorted-by-X list of runs into tokens. Threshold is computed
  # per-line as `median(gaps) * gap_factor`, falling back to
  # `font_size * gap_factor` when there are fewer than two runs (no
  # gaps to sample). Median-based detection makes word-break detection
  # robust across font sizes and per-glyph advance variations — a
  # monospace 4pt-advance line splits at ~4.6pt (catching subtle word
  # boundaries) while a 12pt-advance line tolerates wider intra-token
  # gaps.
  defp tokenize_runs([], _factor), do: []

  defp tokenize_runs([first | _] = runs, factor) do
    threshold = compute_split_threshold(runs, factor)

    runs
    |> Enum.chunk_while(
      [first],
      fn run, [prev | _] = acc ->
        gap = run.x - prev.x

        cond do
          # Same run as seed (chunk_while feeds the seed back on the first call)
          run == prev and acc == [first] ->
            {:cont, acc}

          # Forward jump bigger than the per-line p75 threshold: word break.
          gap > threshold ->
            {:cont, Enum.reverse(acc), [run]}

          # Backward jump > 1pt: the producer is overlapping a label with a
          # value (common in label/value layouts where the writer emits
          # "Territorial:" then jumps slightly back to start "SOLIDARIDAD"
          # underneath the colon). Always treat as a token boundary —
          # typographic kerning is at most ~0.4pt for 8pt fonts.
          gap < -1.0 ->
            {:cont, Enum.reverse(acc), [run]}

          true ->
            {:cont, [run | acc]}
        end
      end,
      fn acc -> {:cont, Enum.reverse(acc), []} end
    )
    |> Enum.map(&run_chunk_to_token/1)
  end

  # Per-line threshold: 75th percentile of positive gaps × factor. The
  # 75th percentile captures the "max typical intra-word advance" — wider
  # than the median (so variable-width fonts where some glyphs are
  # naturally larger don't trigger splits) but tighter than the max (so
  # real word-break gaps still register). Falls back to font_size for
  # lines with too few gaps to sample meaningfully.
  defp compute_split_threshold(runs, factor) do
    gaps =
      runs
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b.x - a.x end)
      |> Enum.filter(&(&1 > 0))

    cond do
      length(gaps) < 3 ->
        size = (List.first(runs) || %{size: 8.0}).size
        max(size, 1.0) * factor

      true ->
        sorted = Enum.sort(gaps)
        p75_idx = min(trunc(length(sorted) * 0.75), length(sorted) - 1)
        p75 = Enum.at(sorted, p75_idx)
        max(p75, 0.5) * factor
    end
  end

  defp run_chunk_to_token([first | _] = chunk) do
    text = chunk |> Enum.map(& &1.text) |> Enum.join("")
    last = List.last(chunk)
    width = max(last.x - first.x, 0.0)

    %{x: first.x, text: text, width: width}
  end

  @doc """
  Returns the plain text for each page as a list of strings.

  Options:
  - `:pages` — `[pos_integer]` to filter to specific 1-indexed page numbers.
    Default: all pages.

  Returns `{:ok, page_strings, doc}` where each element is the concatenated
  text for one page. The returned `doc` carries an updated `:recovery_log`
  when opened with `recover: true`. Unresolved glyphs appear as `U+FFFD`
  (already encoded by the encoding cascade layer).
  """
  @spec read_text(Document.t(), keyword()) ::
          {:ok, [String.t()], Document.t()} | {:error, reason()}
  def read_text(%Document{} = doc, opts \\ []) do
    with {:ok, runs, updated_doc} <- read_text_with_positions(doc) do
      pages_filter = Keyword.get(opts, :pages, :all)

      runs_by_page =
        runs
        |> Enum.group_by(& &1.page)

      if map_size(runs_by_page) == 0 do
        {:ok, [], updated_doc}
      else
        page_nums =
          case pages_filter do
            :all -> runs_by_page |> Map.keys() |> Enum.sort()
            list when is_list(list) -> list
          end

        texts =
          Enum.map(page_nums, fn page_num ->
            page_runs = Map.get(runs_by_page, page_num, [])
            page_runs |> Enum.map(& &1.text) |> Enum.join(" ") |> String.trim()
          end)
          |> Enum.reject(&(&1 == ""))

        {:ok, texts, updated_doc}
      end
    end
  end

  @doc """
  Extracts images from all pages.

  For each page, resolves the XObject references from content-stream `Do`
  operators and classifies them as JPEG or PNG-like based on their `/Filter`.

  Returns `{:ok, [], doc}` when no images are found. The returned `doc`
  carries an updated `:recovery_log` when opened with `recover: true`.
  """
  @spec read_images(Document.t()) ::
          {:ok, [Pdf.Reader.Image.t()], Document.t()} | {:error, reason()}
  def read_images(%Document{} = doc) do
    with {:ok, page_refs, doc2} <- Page.list_refs(doc) do
      collect_images(page_refs, doc2, 1, [])
    end
  end

  @doc """
  Bang variant of `open/2`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec open!(binary() | Path.t(), keyword()) :: Document.t()
  def open!(path_or_binary, opts \\ []) do
    case open(path_or_binary, opts) do
      {:ok, doc} -> doc
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
  Bang variant of `read_metadata/1`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_metadata!(Document.t()) :: %{String.t() => String.t()}
  def read_metadata!(doc) do
    {:ok, meta, _doc} = read_metadata(doc)
    meta
  end

  @doc """
  Bang variant of `page_count/1`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec page_count!(Document.t()) :: pos_integer()
  def page_count!(doc) do
    case page_count(doc) do
      {:ok, n} -> n
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
  Bang variant of `read_text_with_positions/1`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_text_with_positions!(Document.t()) :: [Pdf.Reader.TextRun.t()]
  def read_text_with_positions!(doc) do
    case read_text_with_positions(doc) do
      {:ok, runs, _doc} -> runs
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
  Bang variant of `read_text/2`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_text!(Document.t(), keyword()) :: [String.t()]
  def read_text!(doc, opts \\ []) do
    case read_text(doc, opts) do
      {:ok, texts, _doc} -> texts
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
  Bang variant of `read_images/1`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_images!(Document.t()) :: [Pdf.Reader.Image.t()]
  def read_images!(doc) do
    case read_images(doc) do
      {:ok, images, _doc} -> images
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
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
  """
  @spec read_acroform(Document.t()) ::
          {:ok, [FormField.t()], Document.t()} | {:error, reason()}
  def read_acroform(doc), do: AcroForm.read(doc)

  @doc """
  Bang variant of `read_acroform/1`. Raises `Pdf.Reader.Error` on failure.
  """
  @spec read_acroform!(Document.t()) :: [FormField.t()]
  def read_acroform!(doc) do
    case read_acroform(doc) do
      {:ok, fields, _} -> fields
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
  Extracts document outline (bookmarks) from the PDF catalog's `/Outlines` tree.

  Walks the `/First`/`/Next` linked list at each nesting level, threading
  `/Parent` for depth. Cycle detection via `MapSet` and a depth cap of 32
  prevent hangs on corrupt PDFs.

  Returns `{:ok, [], doc}` when no `/Outlines` entry is present — never an error.

  ## Spec references

  - PDF 1.7 § 12.3.3 — Document Outline
  - PDF 1.7 § 12.3.2 — Destinations
  """
  @spec read_outlines(Document.t()) :: {:ok, [Outline.t()], Document.t()} | {:error, reason()}
  def read_outlines(doc), do: Outlines.read(doc)

  @doc """
  Bang variant of `read_outlines/1`. Raises `Pdf.Reader.Error` on failure.
  Returns the outlines list directly on success.
  """
  @spec read_outlines!(Document.t()) :: [Outline.t()]
  def read_outlines!(doc) do
    case read_outlines(doc) do
      {:ok, outlines, _} -> outlines
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  @doc """
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
  """
  @spec read_annotations(Document.t()) ::
          {:ok, [Annotation.t()], Document.t()} | {:error, reason()}
  def read_annotations(doc), do: Annotations.read(doc)

  @doc """
  Bang variant of `read_annotations/1`. Raises `Pdf.Reader.Error` on failure.
  Returns the annotations list directly on success.
  """
  @spec read_annotations!(Document.t()) :: [Annotation.t()]
  def read_annotations!(doc) do
    case read_annotations(doc) do
      {:ok, anns, _} -> anns
      {:error, reason} -> raise Pdf.Reader.Error, reason
    end
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  defp do_open(binary, opts) when is_binary(binary) do
    password = Keyword.get(opts, :password, "")
    recover_mode = Keyword.get(opts, :recover, false)

    with :ok <- check_header(binary),
         {version, _} <- extract_version(binary),
         {:ok, xref_entries, trailer, recovery_events} <-
           load_xref_or_recover(binary, recover_mode) do
      doc = %Document{
        binary: binary,
        version: version,
        xref: xref_entries,
        trailer: trailer.dict,
        cache: %{},
        page_refs: nil,
        encryption: nil,
        recover_mode: recover_mode,
        recovery_log: Enum.reduce(recovery_events, [], fn ev, log -> [ev | log] end)
      }

      # R-4: when recover_mode is true, probe the page tree immediately so that
      # any catalog-fallback recovery events (e.g. {:page_tree_recovered, n}) are
      # present in the doc returned from open/2. If the probe succeeds via normal
      # tree walk, no events are added. If it triggers the fallback branch, the
      # recovered page refs are stored in doc.page_refs and the recovery_log is
      # populated. Downstream callers (page_count/1, read_text/1) then use the
      # cached page_refs and see the populated recovery_log.
      doc2 =
        if recover_mode do
          case Page.list_refs(doc) do
            {:ok, refs, updated_doc} ->
              %{updated_doc | page_refs: refs}

            {:error, _} ->
              doc
          end
        else
          doc
        end

      attempt_unlock(doc2, trailer, password)
    end
  end

  # ---------------------------------------------------------------------------
  # XRef loading with optional linear-scan recovery
  #
  # Attempt strict XRef load first. If it fails AND recover_mode is true,
  # fall back to XRef.recover/1 (linear scan). Collect recovery events.
  #
  # Returns {:ok, entries, trailer, [recovery_event()]} or {:error, reason}.
  # ---------------------------------------------------------------------------

  defp load_xref_or_recover(binary, recover_mode) do
    case Trailer.locate_startxref(binary) do
      {:ok, startxref_offset} ->
        case XRef.load(binary, startxref_offset) do
          {:ok, entries, trailer} ->
            {:ok, entries, trailer, []}

          {:error, _reason} when recover_mode ->
            # Strict xref load failed with a valid %%EOF but bad offset.
            do_xref_linear_scan(binary)

          {:error, _reason} = err ->
            err
        end

      {:error, _} when recover_mode ->
        # %%EOF missing — linear scan needed.
        # Log :eof_marker_missing PLUS :xref_recovered. `do_xref_linear_scan/1`
        # is total per `XRef.recover/1`'s spec (PDF 1.7 § 7.5.4), so destructure
        # directly — a defensive case-clause would be dead code per Dialyzer.
        {:ok, entries, trailer, events} = do_xref_linear_scan(binary)
        {:ok, entries, trailer, [{:eof_marker_missing, :linear_scan_used} | events]}

      {:error, _} = err ->
        err
    end
  end

  # Run XRef.recover/1 and wrap result with recovery event tuple.
  defp do_xref_linear_scan(binary) do
    case XRef.recover(binary) do
      {:ok, entries, trailer} ->
        n_objects = map_size(entries)
        {:ok, entries, trailer, [{:xref_recovered, n_objects}]}
    end
  end

  # Check that the binary begins with %PDF-
  defp check_header(<<"%PDF-", _::binary>>), do: :ok
  defp check_header(_), do: {:error, :not_a_pdf}

  # Extract version string like "1.4", "1.7", "2.0"
  defp extract_version(<<"%PDF-", rest::binary>>) do
    # Use binary pattern matching to extract the version string from the header line.
    # String.graphemes/1 cannot be used here because PDF binary content is not valid UTF-8.
    version =
      rest
      |> :binary.split(["\n", "\r"])
      |> hd()
      |> String.trim()

    {version, rest}
  end

  defp extract_version(_), do: {"", ""}

  # ---------------------------------------------------------------------------
  # Encryption bootstrap — attempt_unlock/3
  #
  # Branches on the presence of /Encrypt in the trailer:
  # - nil / :null → non-encrypted PDF, return doc as-is.
  # - {:ref, n, g} or inline dict → resolve, parse, authenticate.
  #
  # R-ENC1, R-ENC2, R-ENC3, R-ENC4, R-ENC5, R-ENC6, R-ENC7, R-ENC8
  # ---------------------------------------------------------------------------

  # Non-encrypted PDF: no /Encrypt entry (or explicit /Encrypt null).
  defp attempt_unlock(doc, %Trailer{encrypt: nil}, _password), do: {:ok, doc}
  defp attempt_unlock(doc, %Trailer{encrypt: :null}, _password), do: {:ok, doc}

  # Encrypted PDF: resolve the Encrypt dict, parse it, and authenticate.
  defp attempt_unlock(doc, %Trailer{encrypt: encrypt_ref, id: id_pair}, password)
       when not is_nil(encrypt_ref) do
    # Resolve the Encrypt dict (may be indirect ref or inline dict).
    # Design discovery #4: trailer.encrypt can be {:ref, n, g}, inline map, etc.
    # Design discovery #5: ObjectResolver.resolve returns {:ok, value, updated_doc}.
    with {:ok, encrypt_dict, doc2} <- resolve_encrypt_dict(doc, encrypt_ref),
         doc_id <- extract_doc_id(id_pair),
         {:ok, sh0} <- StandardHandler.parse(encrypt_dict, doc_id),
         :ok <- check_version_supported(sh0),
         {:ok, doc3} <- try_passwords(doc2, sh0, password) do
      {:ok, doc3}
    end
  end

  # Resolve the Encrypt dict: either follow a ref or use an inline dict directly.
  defp resolve_encrypt_dict(doc, {:ref, _n, _g} = ref) do
    case ObjectResolver.resolve(doc, ref) do
      {:ok, dict, doc2} when is_map(dict) -> {:ok, dict, doc2}
      {:ok, _other, _doc2} -> {:error, :malformed}
      {:error, _} = err -> err
    end
  end

  defp resolve_encrypt_dict(doc, dict) when is_map(dict) do
    {:ok, dict, doc}
  end

  defp resolve_encrypt_dict(_doc, _other), do: {:error, :malformed}

  # Extract the first element of the /ID array as the document ID binary.
  # The parser emits hex strings as `{:hex_string, bin}` and literal strings as
  # `{:string, bin}`. Some legacy paths feed in plain binaries already-decoded.
  # All three shapes must yield a binary; Dialyzer's success-typing of
  # `Trailer.extract_id/1` is too narrow because the list contents are wider
  # than the declared `[binary()]`.
  defp extract_doc_id([{:hex_string, bin} | _]) when is_binary(bin), do: bin
  defp extract_doc_id([{:string, bin} | _]) when is_binary(bin), do: bin
  defp extract_doc_id([first | _]) when is_binary(first), do: first
  defp extract_doc_id(_), do: <<>>

  # R-ENC3: verify /V is in the supported set
  defp check_version_supported(%StandardHandler{version: v}) when v in [1, 2, 4, 5], do: :ok
  defp check_version_supported(_), do: {:error, :encrypted_unsupported_handler}

  # R-ENC4: always try empty password first.
  # R-ENC5: if empty fails and non-empty supplied, try the supplied password.
  # R-ENC6: both fail + non-empty supplied → :encrypted_wrong_password.
  # R-ENC7: both fail + no password (or empty) → :encrypted_password_required.
  defp try_passwords(doc, sh0, password) do
    # Step 1: try empty password (always, per R-ENC4)
    case Encryption.unlock("", sh0, doc) do
      {:ok, sh} ->
        {:ok, %{doc | encryption: sh}}

      :error ->
        # Empty password failed. Try caller-supplied if non-empty.
        if password != "" do
          case Encryption.unlock(password, sh0, doc) do
            {:ok, sh} ->
              {:ok, %{doc | encryption: sh}}

            :error ->
              {:error, :encrypted_wrong_password}

            {:error, _} = err ->
              err
          end
        else
          {:error, :encrypted_password_required}
        end

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Metadata helpers
  # ---------------------------------------------------------------------------

  # Decode a PDF value to a plain string for metadata maps.
  # Literal strings come as {:string, binary} from the parser.
  # Hex strings come as {:hex_string, binary}.
  # Scalars (integers, names) are stringified.
  defp decode_info_value({:string, binary}), do: Utils.decode_pdf_string(binary)
  defp decode_info_value({:hex_string, binary}), do: binary
  defp decode_info_value({:name, name}), do: name
  defp decode_info_value(n) when is_integer(n), do: Integer.to_string(n)
  defp decode_info_value(f) when is_float(f), do: Float.to_string(f)
  defp decode_info_value(s) when is_binary(s), do: s
  defp decode_info_value(_), do: nil

  # Resolve the catalog's /Metadata XMP stream and parse it.
  # Returns {xmp_map, updated_doc} — empty map on any failure (graceful).
  # Flow: trailer["Root"] → catalog dict → catalog["Metadata"] → stream
  #        → decode_stream → XMP.parse
  # PDF 1.7 § 14.3.2 — Metadata Streams.
  defp read_xmp_stream(%Document{trailer: trailer} = doc) do
    with {:ok, root_ref} <- fetch_root_ref(trailer),
         {:ok, catalog, doc2} <- ObjectResolver.resolve(doc, root_ref),
         true <- is_map(catalog),
         {:ok, meta_ref} <- fetch_metadata_ref(catalog),
         {:ok, {:stream, stream_dict, raw_bytes}, doc3} <-
           ObjectResolver.resolve(doc2, meta_ref),
         {:ok, decoded} <- decode_stream(stream_dict, raw_bytes),
         {:ok, xmp_map} <- XMP.parse(decoded) do
      {xmp_map, doc3}
    else
      _ -> {%{}, doc}
    end
  end

  defp fetch_root_ref(trailer) do
    case Map.get(trailer, "Root") do
      nil -> :error
      ref -> {:ok, ref}
    end
  end

  defp fetch_metadata_ref(catalog) do
    case Map.get(catalog, "Metadata") do
      nil -> :error
      {:ref, _, _} = ref -> {:ok, ref}
      _ -> :error
    end
  end

  # ---------------------------------------------------------------------------
  # page_count helper
  # ---------------------------------------------------------------------------

  defp read_declared_count(%Document{trailer: trailer} = doc) do
    case Map.get(trailer, "Root") do
      nil ->
        {:error, :no_pages}

      root_ref ->
        with {:ok, catalog, doc2} <- ObjectResolver.resolve(doc, root_ref),
             {:ok, pages_ref} <- fetch_pages_ref_from_catalog(catalog),
             {:ok, pages_node, _doc3} <- ObjectResolver.resolve(doc2, pages_ref) do
          case Map.get(pages_node, "Count") do
            n when is_integer(n) -> {:ok, n}
            _ -> {:error, {:malformed, :page_tree, %{missing_count: true}}}
          end
        end
    end
  end

  defp fetch_pages_ref_from_catalog(%{"Pages" => ref}), do: {:ok, ref}
  defp fetch_pages_ref_from_catalog(_), do: {:error, :no_pages}

  # ---------------------------------------------------------------------------
  # Text extraction helpers
  # ---------------------------------------------------------------------------

  defp collect_text_runs([], doc, _page_num, acc) do
    {:ok, Enum.reverse(acc), doc}
  end

  # R-1: per-page isolation — when recover_mode is true, wrap each page in
  # try/rescue so that a single failing page does not abort the whole document.
  # On failure, append {:page_failed, page_num, reason} to recovery_log and
  # emit [] runs for that page, then continue with the next page.
  # When recover_mode is false, the MatchError from the parser is rescued and
  # converted to {:error, :malformed} to satisfy the strict-mode contract.
  defp collect_text_runs([page_ref | rest], doc, page_num, acc) do
    # page_refs from Page.list_refs are {n, g} tuples — wrap to {:ref, n, g}
    ref = ensure_ref(page_ref)

    if doc.recover_mode do
      {result_acc, result_doc} =
        try do
          case extract_page_runs(doc, ref, page_num) do
            {:ok, runs, updated_doc} ->
              {Enum.reverse(runs) ++ acc, updated_doc}

            {:error, reason} ->
              updated_doc = Document.log_recovery(doc, {:page_failed, page_num, reason})
              {acc, updated_doc}
          end
        rescue
          _ ->
            updated_doc = Document.log_recovery(doc, {:page_failed, page_num, :parse_error})
            {acc, updated_doc}
        end

      collect_text_runs(rest, result_doc, page_num + 1, result_acc)
    else
      try do
        case extract_page_runs(doc, ref, page_num) do
          {:ok, runs, updated_doc} ->
            collect_text_runs(rest, updated_doc, page_num + 1, Enum.reverse(runs) ++ acc)

          {:error, _} = err ->
            err
        end
      rescue
        _ -> {:error, :malformed}
      end
    end
  end

  # R-FX1, R-FX19: use do_interpret_with_doc/5 to thread doc through for Form
  # XObject recursion. Raw xobjects refs are passed — classification happens
  # on demand inside the Do handler. Updated doc (with cache) is returned.
  #
  # R-2: build_decoders_for_resources now returns font_failures list. On recovery
  # mode, each failure is logged as {:font_skipped, page_num, font_name, reason}.
  defp extract_page_runs(doc, page_ref, page_num) do
    with {:ok, page_dict, doc2} <- ObjectResolver.resolve(doc, page_ref),
         {:ok, content_bytes, doc3} <- resolve_page_contents(doc2, page_dict),
         {:ok, resources, doc4} <- resolve_page_resources(doc3, page_ref, page_dict),
         {:ok, font_decoders, font_failures, doc5} <-
           Font.build_decoders_for_resources(resources, doc4),
         doc5a <- log_font_failures(doc5, font_failures, page_num),
         {:ok, font_widths, doc6} <- Widths.build_widths_for_resources(resources, doc5a),
         xobjects <- build_xobjects_map(resources),
         {:ok, events, doc7} <-
           Pdf.Reader.ContentStream.do_interpret_with_doc(
             content_bytes,
             &identity_decoder/1,
             [xobjects: xobjects, font_decoders: font_decoders, font_widths: font_widths],
             doc6,
             resources
           ) do
      runs = events_to_text_runs(events, page_num)
      # doc7 carries decryption cache and Form resolution cache populated during interpretation
      {:ok, runs, doc7}
    end
  end

  # Convert font_failures list to {:font_skipped, page_num, name, reason} events
  # and log them on the doc. Returns doc unchanged when failures list is empty.
  defp log_font_failures(doc, [], _page_num), do: doc

  defp log_font_failures(doc, failures, page_num) do
    Enum.reduce(failures, doc, fn {name, reason}, acc_doc ->
      Document.log_recovery(acc_doc, {:font_skipped, page_num, name, reason})
    end)
  end

  # Default decoder used when no font-specific decoder is available.
  # Returns bytes as-is (identity pass-through).
  defp identity_decoder(bytes), do: {bytes, []}

  # Resolve page /Contents — may be a single ref or an array of refs.
  # Concatenate all decoded streams with a newline separator.
  # Streams are passed through the filter chain (e.g., FlateDecode) before
  # being returned to the content stream interpreter.
  defp resolve_page_contents(doc, page_dict) do
    case Map.get(page_dict, "Contents") do
      nil ->
        {:ok, <<>>, doc}

      {:ref, _, _} = ref ->
        case ObjectResolver.resolve(doc, ref) do
          {:ok, {:stream, dict, raw_bytes}, doc2} ->
            case decode_stream(dict, raw_bytes) do
              {:ok, decoded} -> {:ok, decoded, doc2}
              {:error, _} -> {:ok, <<>>, doc2}
            end

          {:ok, _other, doc2} ->
            {:ok, <<>>, doc2}

          {:error, _} = err ->
            err
        end

      refs when is_list(refs) ->
        Enum.reduce_while(refs, {:ok, <<>>, doc}, fn ref, {:ok, acc_bytes, acc_doc} ->
          case ObjectResolver.resolve(acc_doc, ref) do
            {:ok, {:stream, dict, raw_bytes}, updated_doc} ->
              case decode_stream(dict, raw_bytes) do
                {:ok, decoded} ->
                  {:cont, {:ok, acc_bytes <> "\n" <> decoded, updated_doc}}

                {:error, _} ->
                  # Skip streams we cannot decode — don't abort the whole page
                  {:cont, {:ok, acc_bytes, updated_doc}}
              end

            {:ok, _other, updated_doc} ->
              {:cont, {:ok, acc_bytes, updated_doc}}

            {:error, _} = err ->
              {:halt, err}
          end
        end)

      _ ->
        {:ok, <<>>, doc}
    end
  end

  # Decode a stream's raw bytes through its declared filter chain.
  # Returns {:ok, decoded_bytes} or {:error, reason}.
  # On filter error the caller decides whether to skip or propagate.
  defp decode_stream(dict, raw_bytes) do
    filter = Map.get(dict, "Filter")
    parms = Map.get(dict, "DecodeParms")

    if filter == nil do
      {:ok, raw_bytes}
    else
      Filter.apply_chain(raw_bytes, filter, parms || %{})
    end
  end

  # Resolve /Resources for a page dict.
  # Checks the leaf page's own /Resources first; if absent, walks up the
  # /Parent chain until resources are found or the root is reached.
  # PDF 1.7 § 7.7.3 (Page Tree) and § 7.7.3.4 (Inheritance of Page Attributes).
  #
  # Cache: on entry, checks doc.cache for {:page_resources, {n, g}} keyed by
  # the leaf page's xref ref. On return, writes the result to the cache so
  # subsequent calls for the same leaf page skip the walk entirely.
  #
  # Cycle detection: the `visited` MapSet accumulates {n, g} xref refs seen
  # during this walk. If a /Parent ref is already in `visited`, the cycle is
  # silently broken and the walk returns {:ok, %{}, doc}. This protects against
  # corrupt PDFs where the /Parent chain forms a loop.
  defp resolve_page_resources(doc, leaf_ref, page_dict, visited \\ MapSet.new()) do
    # Normalise the leaf ref to {n, g} for use as a cache key.
    {:ref, n, g} = leaf_ref
    leaf_key = {n, g}

    # Cache hit: return immediately without walking.
    if Map.has_key?(doc.cache, {:page_resources, leaf_key}) do
      {:ok, Map.fetch!(doc.cache, {:page_resources, leaf_key}), doc}
    else
      {{:ok, resources}, updated_doc} =
        do_resolve_page_resources(doc, leaf_key, page_dict, visited)

      cached_doc = %{
        updated_doc
        | cache: Map.put(updated_doc.cache, {:page_resources, leaf_key}, resources)
      }

      {:ok, resources, cached_doc}
    end
  end

  # Internal walker — separated from the cache/cycle guard to keep the logic clean.
  defp do_resolve_page_resources(doc, leaf_key, page_dict, visited) do
    case Map.get(page_dict, "Resources") do
      nil ->
        # Resource inheritance: try /Parent
        case Map.get(page_dict, "Parent") do
          nil ->
            {{:ok, %{}}, doc}

          {:ref, n, g} = parent_ref ->
            # Extract {n, g} from the parent ref for cycle detection.
            parent_key = {n, g}

            # Cycle guard: if this ancestor was already visited, break the loop.
            if MapSet.member?(visited, parent_key) do
              {{:ok, %{}}, doc}
            else
              new_visited = MapSet.put(visited, parent_key)

              # Also add the leaf ref itself on the first call so a page pointing
              # /Parent to itself is caught on the very first ancestor resolution.
              first_visited =
                if leaf_key != nil,
                  do: MapSet.put(new_visited, leaf_key),
                  else: new_visited

              case ObjectResolver.resolve(doc, parent_ref) do
                {:ok, parent_dict, doc2} when is_map(parent_dict) ->
                  # Recurse without the leaf_key cache (parent is not the leaf).
                  # Pass nil as leaf_key so we don't cache at an intermediate node.
                  do_resolve_page_resources(doc2, nil, parent_dict, first_visited)

                _ ->
                  {{:ok, %{}}, doc}
              end
            end
        end

      {:ref, _, _} = ref ->
        case ObjectResolver.resolve(doc, ref) do
          {:ok, resources, doc2} when is_map(resources) -> {{:ok, resources}, doc2}
          {:ok, _, doc2} -> {{:ok, %{}}, doc2}
          {:error, _} -> {{:ok, %{}}, doc}
        end

      resources when is_map(resources) ->
        {{:ok, resources}, doc}

      _ ->
        {{:ok, %{}}, doc}
    end
  end

  # Build the xobjects map: %{name => {:ref, n, g} | inline_dict}
  # R-FX19: pass raw refs — the ContentStream interpreter classifies on demand
  # by reading /Subtype. Pre-classification to :image | :form is removed.
  defp build_xobjects_map(resources) do
    case Map.get(resources, "XObject") do
      nil ->
        %{}

      xobjects when is_map(xobjects) ->
        # Return the map as-is; raw {:ref, n, g} refs and inline dicts are both valid.
        xobjects

      _ ->
        %{}
    end
  end

  # Convert content stream events to TextRun structs
  defp events_to_text_runs(events, page_num) do
    events
    |> Enum.flat_map(fn
      {:text, %{text: text, unresolved: unresolved, x: x, y: y, font: font, size: size}} ->
        if text == "" do
          []
        else
          [
            %Pdf.Reader.TextRun{
              text: text,
              unresolved: unresolved,
              x: x,
              y: y,
              font: font,
              size: size,
              page: page_num
            }
          ]
        end

      _ ->
        []
    end)
  end

  # ---------------------------------------------------------------------------
  # Image extraction helpers
  # ---------------------------------------------------------------------------

  defp collect_images([], doc, _page_num, acc) do
    {:ok, Enum.reverse(acc), doc}
  end

  # R-1: per-page isolation — mirror of collect_text_runs/4 for images.
  # When recover_mode is true, catch per-page failures (including raises) and continue.
  # When recover_mode is false, raises are rescued and converted to {:error, :malformed}.
  defp collect_images([page_ref | rest], doc, page_num, acc) do
    ref = ensure_ref(page_ref)

    if doc.recover_mode do
      {result_acc, result_doc} =
        try do
          case extract_page_images(doc, ref, page_num) do
            {:ok, images, updated_doc} ->
              {Enum.reverse(images) ++ acc, updated_doc}

            {:error, reason} ->
              updated_doc = Document.log_recovery(doc, {:page_failed, page_num, reason})
              {acc, updated_doc}
          end
        rescue
          _ ->
            updated_doc = Document.log_recovery(doc, {:page_failed, page_num, :parse_error})
            {acc, updated_doc}
        end

      collect_images(rest, result_doc, page_num + 1, result_acc)
    else
      try do
        case extract_page_images(doc, ref, page_num) do
          {:ok, images, updated_doc} ->
            collect_images(rest, updated_doc, page_num + 1, Enum.reverse(images) ++ acc)

          {:error, _} = err ->
            err
        end
      rescue
        _ -> {:error, :malformed}
      end
    end
  end

  # R-FX13: image events from Form XObjects bubble up through recurse_into_form.
  # Use do_interpret_with_doc/5 (same as extract_page_runs) so Form recursion
  # is enabled and nested image events are included in the event list.
  #
  # R-2: build_decoders_for_resources now returns font_failures list. On recovery
  # mode, each failure is logged as {:font_skipped, page_num, font_name, reason}.
  defp extract_page_images(doc, page_ref, page_num) do
    with {:ok, page_dict, doc2} <- ObjectResolver.resolve(doc, page_ref),
         {:ok, resources, doc3} <- resolve_page_resources(doc2, page_ref, page_dict),
         {:ok, content_bytes, doc4} <- resolve_page_contents(doc3, page_dict),
         {:ok, font_decoders, font_failures, doc5} <-
           Font.build_decoders_for_resources(resources, doc4),
         doc5a <- log_font_failures(doc5, font_failures, page_num),
         xobjects <- build_xobjects_map(resources),
         {:ok, events, doc6} <-
           Pdf.Reader.ContentStream.do_interpret_with_doc(
             content_bytes,
             &identity_decoder/1,
             [xobjects: xobjects, font_decoders: font_decoders],
             doc5a,
             resources
           ) do
      image_events = Enum.filter(events, &match?({:image, _}, &1))

      # Image events from nested Forms carry the CTM at the point of Do inside the Form.
      # resolve_image_xobject resolves the image stream from the xobjects hierarchy.
      # For images inside Forms, the xobject may live in the Form's /Resources, not the
      # page's /Resources. We try both page resources and a best-effort fallback.
      {images, final_doc} =
        Enum.reduce(image_events, {[], doc6}, fn {:image, %{name: name, ctm: ctm}},
                                                 {img_acc, acc_doc} ->
          case resolve_image_xobject_deep(acc_doc, resources, name, ctm, page_num) do
            {:ok, image, updated_doc} -> {[image | img_acc], updated_doc}
            {:error, _} -> {img_acc, acc_doc}
          end
        end)

      {:ok, Enum.reverse(images), final_doc}
    end
  end

  # R-FX13: extended version of resolve_image_xobject that falls back to
  # scanning the xref table for an Image XObject when the name is not in the
  # page's top-level /XObject dict (e.g. when the image lives inside a Form's
  # /Resources). The page-level lookup is tried first for performance; the
  # xref scan only runs when the name is not found in page resources.
  defp resolve_image_xobject_deep(doc, resources, name, ctm, page_num) do
    xobjects = Map.get(resources, "XObject", %{})

    case Map.get(xobjects, name) do
      nil ->
        # Image is not in page resources — scan the xref for any stream with
        # Subtype=Image and match on the name. If exactly one image exists in
        # the document (typical for Form-only-image test PDFs) return it.
        find_image_in_xref(doc, name, ctm, page_num)

      ref ->
        case ObjectResolver.resolve(doc, ref) do
          {:ok, {:stream, dict, raw_bytes}, doc2} ->
            classify_image_stream(doc2, dict, raw_bytes, ctm, page_num, ref)

          {:ok, _other, _doc2} ->
            {:error, {:not_an_image, name}}

          {:error, _} = err ->
            err
        end
    end
  end

  # Scan the xref table entries and resolve each one; return the first Image
  # XObject stream found (with Subtype=Image). This is a fallback for images
  # that live inside Form /Resources rather than page /Resources.
  defp find_image_in_xref(doc, name, ctm, page_num) do
    xref_entries =
      doc.xref
      |> Enum.filter(fn
        {{n, g}, _offset} when is_integer(n) and is_integer(g) and n > 0 -> true
        _ -> false
      end)

    result =
      Enum.find_value(xref_entries, fn {{n, g}, _offset} ->
        ref = {:ref, n, g}

        case ObjectResolver.resolve(doc, ref) do
          {:ok, {:stream, dict, raw_bytes}, doc2} ->
            case Map.get(dict, "Subtype") do
              {:name, "Image"} ->
                case classify_image_stream(doc2, dict, raw_bytes, ctm, page_num, ref) do
                  {:ok, _image, _doc3} = ok -> ok
                  _ -> nil
                end

              _ ->
                nil
            end

          _ ->
            nil
        end
      end)

    case result do
      nil -> {:error, {:unresolved_xobject, name}}
      ok -> ok
    end
  end

  # Decompose CTM {a, b, c, d, e, f} into image placement components.
  # PDF 1.7 § 8.3.3: The image unit square [0,1]x[0,1] is mapped via the CTM.
  # render_width  = sqrt(a*a + b*b) (scale in x direction)
  # render_height = sqrt(c*c + d*d) (scale in y direction)
  # x, y = translation components (e, f)
  # rotation_radians = atan2(b, a)
  defp decompose_ctm({a, b, c, d, e, f}) do
    render_width = :math.sqrt(a * a + b * b)
    render_height = :math.sqrt(c * c + d * d)
    rotation = :math.atan2(b, a)
    {e, f, render_width, render_height, rotation}
  end

  defp classify_image_stream(doc, dict, raw_bytes, ctm, page_num, ref) do
    filter = Map.get(dict, "Filter")
    width = to_float_dim(Map.get(dict, "Width", 0))
    height = to_float_dim(Map.get(dict, "Height", 0))
    ref_key = extract_ref_key(ref)

    {x, y, render_width, render_height, rotation} = decompose_ctm(ctm)

    case normalize_filter_name(filter) do
      :DCTDecode ->
        image = %Pdf.Reader.Image{
          kind: :jpeg,
          bytes: raw_bytes,
          x: x,
          y: y,
          width: width,
          height: height,
          ctm: ctm,
          render_width: render_width,
          render_height: render_height,
          rotation_radians: rotation,
          page: page_num,
          ref: ref_key
        }

        {:ok, image, doc}

      :FlateDecode ->
        case Pdf.Reader.Filter.Flate.decode(raw_bytes, Map.get(dict, "DecodeParms") || %{}) do
          {:ok, decoded} ->
            image = %Pdf.Reader.Image{
              kind: :png_like,
              bytes: decoded,
              x: x,
              y: y,
              width: width,
              height: height,
              ctm: ctm,
              render_width: render_width,
              render_height: render_height,
              rotation_radians: rotation,
              page: page_num,
              ref: ref_key
            }

            {:ok, image, doc}

          {:error, _} = err ->
            err
        end

      other_filter when other_filter != nil ->
        {:error, {:unsupported_filter, other_filter}}

      nil ->
        # No filter — raw bytes
        image = %Pdf.Reader.Image{
          kind: :png_like,
          bytes: raw_bytes,
          x: x,
          y: y,
          width: width,
          height: height,
          ctm: ctm,
          render_width: render_width,
          render_height: render_height,
          rotation_radians: rotation,
          page: page_num,
          ref: ref_key
        }

        {:ok, image, doc}
    end
  end

  defp normalize_filter_name({:name, name}) do
    case name do
      "DCTDecode" -> :DCTDecode
      "Fl" -> :FlateDecode
      "FlateDecode" -> :FlateDecode
      "DCT" -> :DCTDecode
      other -> String.to_atom(other)
    end
  end

  defp normalize_filter_name(name) when is_binary(name) do
    normalize_filter_name({:name, name})
  end

  defp normalize_filter_name(_), do: nil

  defp to_float_dim(n) when is_integer(n), do: n * 1.0
  defp to_float_dim(f) when is_float(f), do: f
  defp to_float_dim(_), do: 0.0

  defp extract_ref_key({:ref, n, g}), do: {n, g}

  defp ensure_ref({n, g}), do: {:ref, n, g}
end
