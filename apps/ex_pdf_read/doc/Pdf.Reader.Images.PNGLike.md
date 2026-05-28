# `Pdf.Reader.Images.PNGLike`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/images/png_like.ex#L1)

PNG-like image decoding for `Pdf.Reader`.

Handles PDF Image XObjects with `/Filter /FlateDecode` and optional
`/DecodeParms` predictor. After Flate inflation (via `:zlib`) and
predictor un-filtering, the result is raw pixel data.

## API

    decode(stream_bytes, params) :: {:ok, raw_pixels} | {:error, reason}

`stream_bytes` is the raw (still compressed) XObject stream body.
`params` is the XObject dictionary (or its `/DecodeParms` sub-dict) and
should contain:
- `"Width"` (integer)
- `"Height"` (integer)
- `"BitsPerComponent"` (integer, default 8)
- `"ColorSpace"` (name or nil — used to infer number of color components)
- `"Colors"` (integer, default inferred from ColorSpace or 1)
- `"Predictor"` (integer, default 1 = no predictor)
- `"Columns"` (integer, default = Width)

## Spec reference

PDF 1.7 § 7.4.4.4 (FlateDecode filter), § 7.4.4.3 (PNG predictor).
Delegates to `Pdf.Reader.Filter.Flate.decode/2` for the combined inflate +
predictor step — the Flate filter implementation already handles PNG
predictors 10–15 per batch 2.

# `decode`

```elixir
@spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
```

Decodes a FlateDecode-encoded image stream to raw pixel data.

Builds a `DecodeParms` map from the XObject dict and delegates to
`Pdf.Reader.Filter.Flate.decode/2`, which handles both inflation and
PNG predictor un-filtering.

Returns `{:ok, raw_pixel_bytes}` or `{:error, reason}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
