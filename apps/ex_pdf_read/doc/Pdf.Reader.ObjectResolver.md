# `Pdf.Reader.ObjectResolver`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/object_resolver.ex#L1)

Lazy indirect-object resolver with Map-based cache.

Per the design (`sdd/pdf-reader-core/design` § 5 "Lazy Resolution Contract"):

- **Cache**: a plain `Map` on `%Pdf.Reader.Document{}.cache`. No GenServer.
  Key: `{obj_num, gen_num}`. Value: the resolved Elixir term.
- **Signature**: `resolve(doc, {:ref, n, g}) :: {:ok, value, doc} | {:error, reason}`.
  The returned `doc` carries the updated cache. The caller threads `doc` forward
  for cache benefit; dropping the updated doc still yields correct results on
  the next call (re-parse, same value — the binary is immutable).
- **Idempotent**: calling `resolve/2` twice on the same ref with the same doc
  returns the same value. The cache is a hint, not state.

## Resolution paths

1. **Cache hit**: `Map.get(doc.cache, {n, g})` → immediate return.
2. **In-use (classic)**: look up `{n, g}` in `doc.xref` → `{:in_use, offset, _gen}`.
   Slice `binary_part(doc.binary, offset, ...)`, run `Parser.parse_object/1`.
3. **Compressed (ObjStm)**: look up `{n, g}` → `{:compressed, objstm_n, index}`.
   Recursively `resolve(doc, {:ref, objstm_n, 0})`, decode filters, then
   `ObjectStream.fetch/3`.
4. **Free / absent**: `{:error, {:unresolved_ref, {n, g}}}`.

## Ref chasing

`resolve/2` does **NOT** automatically follow nested refs. If a resolved value
is itself `{:ref, _, _}`, the caller decides whether to chase it. This avoids
infinite loops on circular references and keeps the interface predictable.

# `resolve`

```elixir
@spec resolve(Pdf.Reader.Document.t(), {:ref, pos_integer(), non_neg_integer()}) ::
  {:ok, term(), Pdf.Reader.Document.t()} | {:error, term()}
```

Resolve an indirect object reference to its value.

Returns `{:ok, value, updated_doc}` on success, where `updated_doc` has
the resolved value cached. Returns `{:error, reason}` on failure.

The caller should thread the returned `doc` forward to benefit from caching
on subsequent resolutions.

## Error reasons

- `{:error, {:unresolved_ref, {n, g}}}` — ref is absent from xref or is a free entry.
- `{:error, :malformed}` — parse failure.
- `{:error, {:unsupported_filter, name}}` — propagated from filter chain.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
