# `Pdf.Reader.Trailer`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/trailer.ex#L1)

Locates the `startxref` byte offset in a PDF binary and parses the
trailer dictionary at a given xref section offset.

## PDF spec references
- § 7.5.5 — File Trailer
- § 7.5.4 — Cross-Reference Table

# `t`

```elixir
@type t() :: %Pdf.Reader.Trailer{
  dict: map(),
  encrypt: term(),
  id: [{:hex_string, binary()} | {:string, binary()} | binary()] | nil,
  info: Pdf.Reader.Document.ref() | nil,
  prev: non_neg_integer() | nil,
  root: Pdf.Reader.Document.ref() | nil,
  size: pos_integer() | nil
}
```

# `locate_startxref`

```elixir
@spec locate_startxref(binary()) :: {:ok, non_neg_integer()} | {:error, :malformed}
```

Scans `binary` in reverse for `%%EOF`, then reads the `startxref` offset
on the line immediately before it.

Returns `{:ok, offset}` or `{:error, :malformed}`.

Per PDF spec § 7.5.5: the file ends with `%%EOF`. The line above that is
the byte offset to the xref section. The line above that is the keyword
`startxref`.

# `parse`

```elixir
@spec parse(binary(), non_neg_integer()) :: {:ok, t()} | {:error, :malformed}
```

Parses the xref section and trailer dictionary at `offset` within `binary`.

Seeks forward from `offset` to the `trailer` keyword, then parses the
dictionary that follows. Populates a `%Pdf.Reader.Trailer{}` struct.

Returns `{:ok, %Pdf.Reader.Trailer{}}` or `{:error, :malformed}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
