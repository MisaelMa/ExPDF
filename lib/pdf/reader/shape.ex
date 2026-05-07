defmodule Pdf.Reader.Shape do
  @moduledoc """
  Polymorphic struct describing an "interactive" or actionable element
  extracted from a PDF — currently link-like elements (URIs, emails,
  intra-document jumps).

  A shape may come from one of two sources:

  - `:annotation` — a real PDF annotation of subtype `/Link` that the
    document author placed on the page (PDF 1.7 § 12.5.6.5).
  - `:inferred` — a URL or email address that appears as plain text in
    the page content but is not wrapped in a clickable annotation. This
    is common in government forms (e.g. the SAT CSF prints
    `http://sat.gob.mx` as text without making it a link). We pattern-
    match URI and email tokens to surface these to callers.

  ## Fields

  - `:type` — one of `:uri | :email | :goto | :launch | :named`
  - `:page` — 1-indexed page number where the shape lives
  - `:rect` — `{x1, y1, x2, y2}` user-space bounding box, or `nil` when
    the source is `:inferred` and the bounding box could not be derived
    from token positions
  - `:target` — for `:uri`/`:email`: the URI/address as a string. For
    `:goto`: a map `%{page: n}`. For `:launch`/`:named`: see PDF 1.7
    § 12.6.4 — currently surfaced as a raw string when known.
  - `:text` — visible text of the shape (annotation `:contents`, or the
    matched token text for inferred shapes). May be `nil`.
  - `:source` — `:annotation` or `:inferred`

  ## Spec references

  - PDF 1.7 § 12.5.6.5 — Link Annotations:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 12.6.4   — Action types (URI, GoTo, Launch, Named, …)
  - RFC 3986 § 3        — URI Generic Syntax: https://datatracker.ietf.org/doc/html/rfc3986
  - RFC 5321 § 4.1.2    — SMTP Mailbox/Domain syntax (for `mailto:`):
    https://datatracker.ietf.org/doc/html/rfc5321
  """

  @type type :: :uri | :email | :goto | :launch | :named
  @type source :: :annotation | :inferred
  @type rect :: {number(), number(), number(), number()}
  @type target :: String.t() | %{page: pos_integer()} | nil

  @type t :: %__MODULE__{
          type: type(),
          page: pos_integer(),
          rect: rect() | nil,
          target: target(),
          text: String.t() | nil,
          source: source()
        }

  defstruct [:type, :page, :rect, :target, :text, :source]
end
