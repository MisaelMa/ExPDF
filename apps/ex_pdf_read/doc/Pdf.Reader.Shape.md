# `Pdf.Reader.Shape`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/shape.ex#L1)

Polymorphic struct describing an "interactive" or actionable element
extracted from a PDF — currently link-like elements (URIs, emails,
intra-document jumps).

A shape may come from one of three sources:

- `:annotation` — a real PDF annotation of subtype `/Link` that the
  document author placed on the page (PDF 1.7 § 12.5.6.5).
- `:inferred` — a URL or email address that appears as plain text in
  the page content but is not wrapped in a clickable annotation. This
  is common in government forms (e.g. the SAT CSF prints
  `http://sat.gob.mx` as text without making it a link). We pattern-
  match URI and email tokens to surface these to callers.
- `:embedded` — a non-text element drawn into the page content
  (currently raster images via `Do` operators on `/Subtype /Image`
  XObjects, PDF 1.7 § 8.9). The reader surfaces these so callers
  can know an image exists at a position even if they can't decode
  its contents (e.g. a QR code rendered as PNG).

## Fields

- `:type` — one of `:uri | :email | :goto | :launch | :named | :image`
- `:page` — 1-indexed page number where the shape lives
- `:rect` — `{x1, y1, x2, y2}` user-space bounding box, or `nil` when
  the source is `:inferred` and the bounding box could not be derived
  from token positions
- `:target` — for `:uri`/`:email`: the URI/address as a string. For
  `:goto`: a map `%{page: n}`. For `:image`: the indirect ref
  `{n, g}` of the underlying XObject. For `:launch`/`:named`: see
  PDF 1.7 § 12.6.4 — currently surfaced as a raw string when known.
- `:text` — visible text of the shape (annotation `:contents`, or the
  matched token text for inferred shapes). `nil` for images.
- `:source` — `:annotation`, `:inferred`, or `:embedded`
- `:meta` — type-specific extras as a map. For `:image`:
  `%{format: :png_like | :jpeg, width: w, height: h, byte_size: n}`.
  Empty for link-like shapes today; future kinds (`:button`,
  `:form_field`) will populate it.

## Spec references

- PDF 1.7 § 8.9         — Images (XObject /Subtype /Image):
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 12.5.6.5    — Link Annotations
- PDF 1.7 § 12.6.4      — Action types (URI, GoTo, Launch, Named, …)
- RFC 3986 § 3          — URI Generic Syntax: https://datatracker.ietf.org/doc/html/rfc3986
- RFC 5321 § 4.1.2      — SMTP Mailbox/Domain syntax (for `mailto:`):
  https://datatracker.ietf.org/doc/html/rfc5321

# `rect`

```elixir
@type rect() :: {number(), number(), number(), number()}
```

# `source`

```elixir
@type source() :: :annotation | :inferred | :embedded
```

# `t`

```elixir
@type t() :: %Pdf.Reader.Shape{
  meta: map(),
  page: pos_integer(),
  rect: rect() | nil,
  source: source(),
  target: target(),
  text: String.t() | nil,
  type: type()
}
```

# `target`

```elixir
@type target() ::
  String.t() | %{page: pos_integer()} | {pos_integer(), non_neg_integer()} | nil
```

# `type`

```elixir
@type type() :: :uri | :email | :goto | :launch | :named | :image
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
