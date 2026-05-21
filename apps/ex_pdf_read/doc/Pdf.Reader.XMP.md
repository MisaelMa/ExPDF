# `Pdf.Reader.XMP`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/xmp.ex#L1)

XMP RDF/XML metadata parser.

Extracts a flat `%{String.t() => String.t()}` map keyed by /Info-compatible
names ("Title", "Author", "Subject", "Description", "Creator", "Producer",
"CreationDate", "ModDate", "Keywords") from a catalog `/Metadata` XMP packet.

## Recognized namespaces (URI-based, not prefix-based)

- `http://purl.org/dc/elements/1.1/` (dc) — Dublin Core
- `http://ns.adobe.com/xap/1.0/` (xmp) — XMP Basic
- `http://ns.adobe.com/pdf/1.3/` (pdf) — PDF
- `http://www.w3.org/1999/02/22-rdf-syntax-ns#` (rdf) — RDF containers

## Mapping to /Info keys

- dc:title → "Title"
- dc:creator (rdf:Bag, **first element only**) → "Author"
- dc:subject (rdf:Bag, first element) → "Subject"
- dc:description (rdf:Alt) → **"Description"** (distinct from "Subject")
- xmp:CreateDate → "CreationDate"
- xmp:ModifyDate → "ModDate"
- xmp:CreatorTool → "Creator"
- pdf:Producer → "Producer"
- pdf:Keywords → "Keywords"

## Error handling

Malformed XML returns `{:error, :malformed_xmp}` — never raises. Empty
rdf:RDF document returns `{:ok, %{}}`.

## Spec references
- PDF 1.7 (ISO 32000-1) § 14.3.2 — Metadata Streams:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- XMP Specification Part 1 (data model, serialization):
  https://github.com/adobe/xmp-docs/raw/master/XMPSpecificationPart1.pdf
- W3C RDF/XML Syntax Specification:
  https://www.w3.org/TR/rdf-syntax-grammar/

# `parse`

```elixir
@spec parse(binary()) ::
  {:ok, %{required(String.t()) =&gt; String.t()}} | {:error, :malformed_xmp}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
