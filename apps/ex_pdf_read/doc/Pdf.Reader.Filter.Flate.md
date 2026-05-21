# `Pdf.Reader.Filter.Flate`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/filter/flate.ex#L1)

FlateDecode filter — zlib inflate, with optional PNG and TIFF predictor
un-filtering.

## Predictor support

Predictor values in `/DecodeParms`:
- `1` (default) — no predictor.
- `2` — TIFF Predictor 2 (horizontal differencing), applied row-by-row.
- `10` — PNG None (row type 0 prefix consumed and discarded).
- `11` — PNG Sub.
- `12` — PNG Up.
- `13` — PNG Average.
- `14` — PNG Paeth.
- `15` — PNG Optimal (decoder treats row-type byte as the actual filter; this is
  the same as having per-row filter selection — just read the type byte per row).

## DecodeParms keys

| Key                | Default | Meaning                                    |
|--------------------|---------|--------------------------------------------|
| `"Predictor"`      | `1`     | Predictor type (1 = none)                  |
| `"Columns"`        | `1`     | Row width in samples                       |
| `"Colors"`         | `1`     | Number of color components per sample      |
| `"BitsPerComponent"` | `8`  | Bits per component                         |

# `decode`

```elixir
@spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
```

Inflate a zlib-compressed binary, then apply any configured predictor.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
