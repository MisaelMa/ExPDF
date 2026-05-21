# `Pdf.Reader.Result`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/result.ex#L1)

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

# `t`

```elixir
@type t() :: %Pdf.Reader.Result{meta: map(), pages: [Pdf.Reader.Result.Page.t()]}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
