# `Pdf.Reader.XRef`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/xref.ex#L1)

Facade that dispatches to the appropriate xref reader and follows /Prev chains.

## Dispatch logic (PDF 1.7 § 7.5.8)

At a given `startxref` offset, peeks at the first non-whitespace bytes:

- Starts with `xref` → **classic** xref table (§ 7.5.4). Delegates to
  `Pdf.Reader.XRef.Classic`.
- Starts with digits matching `N G obj` → **xref stream** (§ 7.5.8).
  Delegates to `Pdf.Reader.XRef.Stream`.

Both formats carry `/Prev` chain links that reference older xref sections.
Those are followed recursively, with newer entries overriding older ones.

## Hybrid PDFs

Incremental updates may mix classic and stream xrefs in the same /Prev chain.
`load/2` handles this transparently by dispatching each chain link independently.

## Linear scan recovery (PDF 1.7 § 7.5.4, § 7.5.8)

When normal xref loading fails (corrupt or missing `%%EOF`, bad `startxref`
offset), `recover/1` performs a linear scan of the full PDF binary to
reconstruct the cross-reference table without relying on the `startxref`
pointer or the on-disk xref section.

Algorithm:
1. Use `:binary.matches/2` to find all occurrences of `" obj"` in the binary.
2. Back-scan each match for a `\n<digits> <digits> ` prefix — this distinguishes
   real object headers from `obj` substrings inside content streams or strings.
3. Build a map of `{obj_num, gen_num} => {:in_use, offset, gen_num}` entries.
4. On collision (same `obj_num`, different `gen_num`), keep the highest
   `gen_num`; ties are broken by the later (higher) byte offset.
5. Synthesise a trailer dict by scanning the binary for the LAST
   `trailer\n<<...>>` block. If none is found, scan recovered object entries
   for one containing `/Type /Catalog` to derive `/Root`.
6. Returns `{:ok, entries_map, trailer_struct}`.

## Spec references

- PDF 1.7 § 7.5.4 — Cross-reference table
- PDF 1.7 § 7.5.5 — File trailer
- PDF 1.7 § 7.5.8 — Cross-reference streams

# `entries`

```elixir
@type entries() :: %{required(Pdf.Reader.Document.ref()) =&gt; entry()}
```

# `entry`

```elixir
@type entry() :: Pdf.Reader.Document.xref_entry()
```

# `load`

```elixir
@spec load(binary(), non_neg_integer()) ::
  {:ok, entries(), Pdf.Reader.Trailer.t()} | {:error, term()}
```

Loads all xref sections reachable from `start_offset` (following `/Prev` links)
and merges them into a single entries map.

Newer sections' entries override older ones on conflict (reverse-chain order).

Returns `{:ok, entries_map, trailer_struct}` or `{:error, reason}`.

# `recover`

```elixir
@spec recover(binary()) :: {:ok, entries(), Pdf.Reader.Trailer.t()}
```

Recovers a cross-reference table from a PDF binary by linear scan, without
relying on `startxref` or any xref section in the file.

## Algorithm

1. Use `:binary.matches/2` to find every `" obj"` substring in `binary`.
2. For each match position, back-scan to validate the `\n<digits> <digits> `
   prefix that characterises a real indirect-object header. This rejects false
   positives where `obj` appears inside a content stream or string literal.
3. Parse `(obj_num, gen_num)` from the prefix and compute the byte offset of
   the object (start of `N G obj`).
4. Deduplicate by `obj_num`: when the same number appears more than once keep
   the entry with the highest `gen_num`. If `gen_num` values tie, the entry
   at the larger byte offset wins (later in the file = more recent revision).
5. Synthesise a `%Pdf.Reader.Trailer{}` by scanning for the last
   `trailer\n<<...>>` block. If none is found, scan recovered entries for an
   object whose dict contains `/Type /Catalog` and use its ref as `/Root`.

Returns `{:ok, entries_map, trailer_struct}` where `entries_map` is keyed by
`{obj_num, gen_num}` tuples.

PDF 1.7 § 7.5.4 — Cross-reference table
PDF 1.7 § 7.5.8 — Cross-reference streams

---

*Consult [api-reference.md](api-reference.md) for complete listing*
