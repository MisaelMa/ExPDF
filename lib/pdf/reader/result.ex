defmodule Pdf.Reader.Result do
  @moduledoc """
  Unified extraction result returned by `Pdf.Reader.read/2`.

  ## Shape

      %Pdf.Reader.Result{
        meta: %{                              # document-level metadata
          title: "..." | nil,
          author: "..." | nil,
          subject: "..." | nil,
          keywords: "..." | nil,
          creator: "..." | nil,
          producer: "..." | nil,
          creation_date: "..." | nil,
          mod_date: "..." | nil,
          version: "1.7",
          page_count: 2,
          encrypted: false,
          recovery_log: [],                   # see Pdf.Reader.recovery_log/1
          raw: %{...}                         # the full Info-dict + XMP merge
        },
        pages: [
          %Pdf.Reader.Result.Page{
            number: 1,                        # 1-indexed
            meta: %{},                        # reserved for page-level info
            lines: [%Pdf.Reader.Line{}, ...]  # text + image lines, top-to-bottom
          },
          ...
        ]
      }

  Each line's tokens carry `:kind` and `:shape` so the caller can tell
  whether each token is text, link, email or image — see `Pdf.Reader.Line`
  and `Pdf.Reader.Shape`.

  Standard PDF 1.7 (ISO 32000-1) Info-dictionary keys are normalised to
  atom keys (`:title`, `:author`, etc.) for ergonomic access. The raw
  string-keyed map (Info ∪ XMP) is preserved at `meta.raw` so callers
  that need vendor-specific fields (e.g. Oracle XML Publisher's
  `"Type"` key) can still retrieve them.

  ## Spec references

  - PDF 1.7 § 14.3.3   — Document Information Dictionary (Info entries):
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 14.3.2   — Metadata Streams (XMP)
  - PDF 1.7 § 7.7.3    — Page Tree
  """

  defmodule Page do
    @moduledoc """
    Per-page slice of the unified extraction result.

    `:lines` contains both text lines (with `:kind`-tagged tokens
    including `:link`, `:email`, `:image`) and synthetic image-only
    lines, sorted top-to-bottom on the page.

    Spec reference: PDF 1.7 § 7.7.3 — Page Tree.
    """

    @type t :: %__MODULE__{
            number: pos_integer(),
            meta: map(),
            lines: [Pdf.Reader.Line.t()]
          }

    defstruct number: 1, meta: %{}, lines: []
  end

  @type t :: %__MODULE__{
          meta: map(),
          pages: [Page.t()]
        }

  defstruct meta: %{}, pages: []
end
