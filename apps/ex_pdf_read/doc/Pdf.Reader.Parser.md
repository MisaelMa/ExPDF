# `Pdf.Reader.Parser`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/parser.ex#L1)

PDF recursive-descent parser.

Converts a PDF binary into the tagged-tuple internal value representation
defined in the design:

  - integers → `integer()`
  - reals → `float()`
  - booleans → `true | false`
  - null → `:null`
  - names → `{:name, binary()}`
  - literal strings → `{:string, binary()}`
  - hex strings → `{:hex_string, binary()}`
  - arrays → Elixir `list()`
  - dictionaries → `%{binary() => value()}` (keys without leading `/`)
  - indirect refs → `{:ref, n, g}`
  - streams → `{:stream, dict_map, raw_bytes}`

References are NEVER resolved here — they come out as `{:ref, n, g}` tuples
for lazy resolution by `Pdf.Reader.ObjectResolver`.

# `parse_object`

```elixir
@spec parse_object(binary()) ::
  {:ok, {pos_integer(), non_neg_integer()}, term(), binary()} | {:error, term()}
```

Parses a full indirect object `N G obj <value> endobj` from `binary`.

Returns `{:ok, {n, g}, value, rest}` on success, or `{:error, reason}` on failure.

For stream objects the value is `{:stream, dict_map, raw_bytes}` where
`raw_bytes` is the UNFILTERED payload.

# `parse_value`

```elixir
@spec parse_value(binary()) :: {term(), binary()}
```

Parses a single PDF value from `binary`. Returns `{value, rest}`.

The `rest` binary is the unconsumed input after the value ends.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
