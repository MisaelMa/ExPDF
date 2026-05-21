# `Pdf.Reader.Filter.ASCIIHex`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/filter/ascii_hex.ex#L1)

ASCIIHexDecode filter — decodes a sequence of hexadecimal digit pairs to
a binary.

Rules (per PDF spec §7.4.2):
- Whitespace (space, tab, CR, LF, FF, null) is ignored between pairs.
- `>` (0x3E) is the end-of-data (EOD) marker; any bytes after it are ignored.
- If the number of hex digits before EOD is odd, the last digit is padded
  with a trailing `0` nibble.
- All other characters are an error.

# `decode`

```elixir
@spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
```

Decode ASCIIHex-encoded bytes.

`params` is accepted but ignored (no DecodeParms defined for this filter).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
