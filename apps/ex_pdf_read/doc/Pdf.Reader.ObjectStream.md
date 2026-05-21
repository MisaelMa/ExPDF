# `Pdf.Reader.ObjectStream`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/object_stream.ex#L1)

Decodes objects embedded in a PDF Object Stream (`/Type /ObjStm`).

Per PDF 1.7 ISO 32000-1 § 7.5.7 "Object Streams":

An Object Stream is a stream whose **decoded** body has two parts:

1. **Header**: `N` whitespace-separated pairs `obj_num offset`, where
   `offset` is the byte offset of that object's value **relative to `/First`**.
2. **Object values**: starting at byte `/First`, the `N` object bodies
   concatenated. Each body is a PDF value (integer, name, dictionary, array,
   etc.) but **never** a stream object — embedded streams are forbidden.

## Caller contract

The caller (object resolver) is responsible for:
1. Resolving the ObjStm indirect object itself.
2. Decoding its filter chain (FlateDecode etc.) to get the raw body binary.
3. Calling `fetch/3` with the decoded body, the `/First` offset, and
   the desired object's 0-based index within the stream.

This design avoids a circular dependency between the resolver and ObjStm:
the resolver is stateful (cache), ObjStm is pure (binary in, value out).

## Error reasons

- `{:error, :objstm_index_out_of_range}` — index ≥ N (the object count).
- `{:error, :malformed}` — header cannot be parsed.

# `fetch`

```elixir
@spec fetch(non_neg_integer(), binary(), non_neg_integer()) ::
  {:ok, term()} | {:error, term()}
```

Fetch the PDF value at 0-based `index` from a decoded ObjStm body.

`first` is the `/First` value from the stream dictionary — the byte offset
within `body` where object data starts.

`body` is the **decoded** (filtered) stream body binary.

Returns `{:ok, value}` or `{:error, reason}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
