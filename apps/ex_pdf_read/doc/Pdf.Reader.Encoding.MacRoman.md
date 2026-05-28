# `Pdf.Reader.Encoding.MacRoman`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/encoding/mac_roman.ex#L1)

Mac OS Roman (MacRomanEncoding) byte-to-Unicode codepoint table.

Used by PDF readers to decode single-byte character codes for fonts
that specify `/Encoding /MacRomanEncoding` (or omit an encoding and
use a Mac-origin Type 1 font).

The table is generated at compile time from `priv/mac_roman.txt`,
which is the canonical mapping published by Apple at
<https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/ROMAN.TXT>.
Bytes that are not present in the source file return `:undefined`.

# `decode`

```elixir
@spec decode(0..255) :: non_neg_integer() | :undefined
```

Decode a single byte to a Unicode codepoint.

Returns `:undefined` for bytes that have no mapping in Mac OS Roman.

# `entry_count`

```elixir
@spec entry_count() :: non_neg_integer()
```

Returns the number of byte→codepoint entries loaded from priv/mac_roman.txt.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
