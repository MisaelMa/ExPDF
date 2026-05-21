# `Pdf.Reader.Filter.RLE`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/filter/rle.ex#L1)

RunLengthDecode filter — decodes PackBits-style run-length encoded data.

Per PDF spec §7.4.5:
- Length byte 128 → end of data (EOD).
- Length byte 0–127 → copy the next `n + 1` bytes verbatim (literal run).
- Length byte 129–255 → repeat the next byte `257 - n` times (run).

# `decode`

```elixir
@spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
```

Decode RunLength-encoded bytes. `params` is ignored.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
