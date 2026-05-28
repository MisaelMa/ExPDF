# `Pdf.Reader.CMap`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/cmap.ex#L1)

Parser for the ToUnicode CMap subset used in PDF fonts.

Spec reference: PDF 1.7 § 9.10.3 and Adobe Tech Note 5099
(CMap and CIDFont Files Specification).

## Supported subset

Only `beginbfchar`/`endbfchar` and `beginbfrange`/`endbfrange` sections
are parsed. Everything else (codespacerange, cidchar, cidrange, notdefchar,
notdefrange, and PostScript prologue/epilogue) is silently skipped.

## Data shape

    %Pdf.Reader.CMap{
      bf_char: %{integer => String.t()},       # O(log n) map lookup
      bf_range: [{lo, hi, dst}]                # linear scan, dst is String.t() or [String.t()]
    }

## Lookup order

1. `bf_char` (O(log n) map) — checked first.
2. `bf_range` (linear, typically < 10 entries) — checked on miss.

Returns `nil` if not mapped by either table.

## UTF-16BE decoding

Hex strings in the CMap (`<HHHH...>`) are UTF-16BE encoded codepoint sequences.
Erlang's `:unicode.characters_to_binary/3` converts them to UTF-8 (Elixir `String.t()`).

# `t`

```elixir
@type t() :: %Pdf.Reader.CMap{
  bf_char: %{required(non_neg_integer()) =&gt; String.t()},
  bf_range: [{non_neg_integer(), non_neg_integer(), String.t() | [String.t()]}]
}
```

# `lookup`

```elixir
@spec lookup(t(), non_neg_integer()) :: String.t() | nil
```

Looks up a character code in the CMap.

Returns the corresponding UTF-8 `String.t()` or `nil` if not mapped.
Lookup order: `bf_char` first (O(log n)), then `bf_range` (linear scan).

# `parse`

```elixir
@spec parse(binary()) :: t()
```

Parses a ToUnicode CMap binary into a `%Pdf.Reader.CMap{}` struct.

Only `bfchar` and `bfrange` sections are extracted.
All other PostScript CMap constructs are skipped silently.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
