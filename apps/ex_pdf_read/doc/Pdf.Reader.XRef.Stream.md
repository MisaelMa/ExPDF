# `Pdf.Reader.XRef.Stream`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/xref/stream.ex#L1)

Parses a PDF 1.5+ compressed cross-reference stream (`/Type /XRef`).

Per PDF 1.7 ISO 32000-1 § 7.5.8 "Cross-Reference Streams":

- The stream object dictionary must have `/Type /XRef`.
- Required fields: `/Size` (total object count), `/W [w1 w2 w3]` (byte widths).
- Optional `/Index [first count ...]` — subsection ranges; default `[0 /Size]`.
- Optional `/Prev` — byte offset of previous xref section (chain support).
- The stream body (after decoding all filters) contains exactly
  `w1 + w2 + w3` bytes per entry:
    - Field 1 (w1 bytes): entry type. If w1 = 0, type is implicitly 1.
    - Field 2 (w2 bytes): meaning depends on type.
    - Field 3 (w3 bytes): meaning depends on type.

Entry types (§ 7.5.8 Table 18):
- **Type 0** (free): f2 = next free object number, f3 = generation when reused.
- **Type 1** (in-use, classic): f2 = byte offset, f3 = generation number.
- **Type 2** (compressed): f2 = object number of containing ObjStm, f3 = index within it.

This module decodes the stream body using `Pdf.Reader.Filter.apply_chain/3`,
which handles `FlateDecode` and PNG predictors transparently (batch 1 impl).

# `parse`

```elixir
@spec parse({:stream, map(), binary()}) ::
  {:ok,
   %{required(Pdf.Reader.Document.ref()) =&gt; Pdf.Reader.Document.xref_entry()}}
  | {:error, term()}
```

Parses a `/Type /XRef` stream object tuple into an xref entries map.

Accepts `{:stream, dict, raw_bytes}` where `raw_bytes` is the still-encoded
(FlateDecode-compressed) stream body.

Returns:
- `{:ok, entries_map}` — map of `{obj_num, gen_num} => entry`
- `{:error, :not_an_xref_stream}` — dict does not have `/Type /XRef`
- `{:error, reason}` — filter/decoding error propagated from the filter chain

---

*Consult [api-reference.md](api-reference.md) for complete listing*
