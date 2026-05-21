# `Pdf.Reader.Filter`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.1/lib/pdf/reader/filter.ex#L1)

PDF stream filter pipeline — behaviour definition and apply_chain dispatcher.

Each filter is a module implementing the `Pdf.Reader.Filter` behaviour with
a single `decode/2` callback. The `apply_chain/3` function runs filters
in sequence (outermost first, matching the order in which they appear in
the PDF stream's `/Filter` array).

## Supported filters

| Module                      | Filter names                          |
|-----------------------------|---------------------------------------|
| `Pdf.Reader.Filter.Flate`   | `FlateDecode`, `Fl`                   |
| `Pdf.Reader.Filter.ASCII85` | `ASCII85Decode`, `A85`                |
| `Pdf.Reader.Filter.ASCIIHex`| `ASCIIHexDecode`, `AHx`               |
| `Pdf.Reader.Filter.RLE`     | `RunLengthDecode`, `RL`               |
| `Pdf.Reader.Filter.LZW`     | `LZWDecode`, `LZW`                    |

Unknown filters return `{:error, {:unsupported_filter, name_atom}}`.

# `decode`

```elixir
@callback decode(binary(), params :: map()) :: {:ok, binary()} | {:error, term()}
```

# `apply_chain`

```elixir
@spec apply_chain(
  binary(),
  names :: list() | binary() | atom(),
  params :: list() | map()
) ::
  {:ok, binary()} | {:error, term()}
```

Apply a chain of filters to `bytes`.

`names` may be:
- A list of filter name strings or atoms (multi-filter case)
- A single filter name string or atom (single-filter convenience)

`params` may be:
- A list of param maps (aligned with `names`)
- A single map (used for all filters)
- `:null` entries in the list become `%{}`

Filters are applied left to right (outermost first per PDF spec).
Returns `{:ok, decoded_bytes}` or `{:error, reason}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
