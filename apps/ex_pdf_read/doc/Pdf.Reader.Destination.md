# `Pdf.Reader.Destination`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/destination.ex#L1)

Destination resolution for outline and annotation `/Dest` values.

Handles 4 variants:
1. Direct array `[<page-ref> /XYZ x y zoom]` — first element is a page ref.
2. Named string — looked up in catalog `/Names /Dests` name tree.
3. `/A /S /GoTo /D <array>` — array variant inside an action dict.
4. `/A /S /GoTo /D <name>` — named variant inside an action dict.

Unresolvable destinations return `{:ok, nil, doc}` — no error is raised.

## Spec references

- PDF 1.7 § 12.3.2 — Destinations:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 12.6 — Actions
- PDF 1.7 § 7.9.6 — Name Trees

# `build_named_dest_index`

```elixir
@spec build_named_dest_index(Pdf.Reader.Document.t()) ::
  {:ok, %{required(String.t()) =&gt; list()}, Pdf.Reader.Document.t()}
```

Builds (and caches) a flat `%{name => dest_array}` map from the catalog's
`/Names /Dests` name tree.

The result is cached in `doc.cache[:named_dest_index]`. If the catalog has
no `/Names` or `/Dests` entry, returns `{:ok, %{}, doc}`.

Name tree traversal:
- Visits ALL `/Kids` (does NOT binary-search via `/Limits` — corrupt PDFs
  may violate sort order).
- Depth cap: `@max_name_tree_depth 20` — nodes beyond depth 20 are skipped.
- Cycle guard: `MapSet` of `{obj_num, gen_num}` to prevent infinite loops.

# `ensure_page_index`

```elixir
@spec ensure_page_index(Pdf.Reader.Document.t()) ::
  {:ok, %{required({pos_integer(), non_neg_integer()}) =&gt; pos_integer()},
   Pdf.Reader.Document.t()}
```

Ensures the page-ref index is built and returns it.

The index maps `{obj_num, gen_num}` refs to 1-indexed page numbers.
The result is cached in `doc.cache[:page_ref_index]` — subsequent calls
return the cached value without re-traversing the page tree.

## Example

    {:ok, index, doc} = Pdf.Reader.Destination.ensure_page_index(doc)
    page_num = Map.get(index, {3, 0})  # => 1

# `resolve`

```elixir
@spec resolve(any(), Pdf.Reader.Document.t(), %{
  required({pos_integer(), non_neg_integer()}) =&gt; pos_integer()
}) :: {:ok, pos_integer() | nil, Pdf.Reader.Document.t()}
```

Resolves a destination value to a 1-indexed page number.

Accepts any of the 4 dest variants described in the moduledoc. Returns
`{:ok, page_num, doc}` where `page_num` is a positive integer or `nil`
when the destination cannot be resolved.

The returned `doc` may have a warmer cache than the input.

## Parameters

- `dest` — the raw dest value from the PDF dict (see variants above)
- `doc` — the `%Pdf.Reader.Document{}` to resolve against
- `page_index` — a `%{{obj_num, gen_num} => page_num_1indexed}` map;
  obtain via `ensure_page_index/1`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
