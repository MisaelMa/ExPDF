# `Pdf.Reader.Filter.LZW`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/filter/lzw.ex#L1)

LZWDecode filter — decodes LZW compressed data as specified in PDF §7.4.4.

## Code parameters

- Initial code width: 9 bits.
- Clear code: 256 (resets the table to the initial state).
- EOD code: 257 (end of data).
- Code width increases from 9 to 12 bits as the table grows.

## EarlyChange

Controlled by the `"EarlyChange"` key in DecodeParms (default: `1`).

- `EarlyChange 1` (PDF default): the code width increases when the table
  has `2^current_width - 1` entries (i.e., BEFORE the table is full).
- `EarlyChange 0`: width increases AFTER the table reaches `2^current_width`
  entries (i.e., when the NEXT code would overflow).

## Predictor

LZW supports the same predictor params as FlateDecode. After decoding the
LZW bit stream the predictor is applied via `Pdf.Reader.Filter.Flate`'s
predictor logic (delegated — same code path).

# `decode`

```elixir
@spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
```

Decode LZW-compressed bytes. `params` may include `"EarlyChange"` (default 1).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
