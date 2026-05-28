# `Pdf.Reader.Filter.ASCII85`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/filter/ascii85.ex#L1)

ASCII85Decode filter — decodes ASCII base-85 encoded data to binary.

Per PDF spec §7.4.3:
- Characters `!` (0x21) through `u` (0x75) encode 5-char groups to 4 bytes.
- `z` is a shortcut for a group of 5 `!` characters (representing 4 zero bytes).
- `~>` is the end-of-data (EOD) marker; any subsequent bytes are ignored.
- Whitespace (space, tab, CR, LF, FF) is ignored.
- Partial final group (1–4 chars) maps to 1–3 output bytes using padding.

# `decode`

```elixir
@spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
```

Decode ASCII85-encoded bytes. `params` is ignored.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
