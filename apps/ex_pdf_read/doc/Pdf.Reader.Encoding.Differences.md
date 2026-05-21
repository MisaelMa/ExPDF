# `Pdf.Reader.Encoding.Differences`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/encoding/differences.ex#L1)

Applies a PDF `/Differences` array on top of a base encoding override map.

Spec reference: PDF 1.7 § 9.6.5.1.

## Format

`/Differences` is an array mixing integers and names:

    [32 /space 65 /A /B /C 200 /uni0024 ...]

- An integer `N` sets the current code position to `N`.
- Each subsequent name installs that glyph name at position, then increments by 1.

## API

    apply(base_overrides, differences_array) :: %{integer() => glyph_name :: binary()}

The output is a byte→glyph_name map. Codepoint resolution (via AGL or ToUnicode)
happens later in the encoding facade (`Pdf.Reader.Encoding`).

`/Differences` entries override the base map. Base entries not touched by
`/Differences` are preserved.

# `apply`

```elixir
@spec apply(%{required(non_neg_integer()) =&gt; binary()}, list()) :: %{
  required(non_neg_integer()) =&gt; binary()
}
```

Applies a `/Differences` array on top of `base`, returning the merged
byte→glyph_name override map.

`differences` is a list of integers and `{:name, binary()}` tuples, matching
the tagged-tuple convention used by the reader's parser.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
