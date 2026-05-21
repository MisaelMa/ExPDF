# `Pdf.Reader.XRef.Classic`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/xref/classic.ex#L1)

Parses a classic PDF cross-reference table (keyword `xref`).

Per PDF spec § 7.5.4:
- Starts with the `xref` keyword on its own line.
- Followed by one or more subsections. Each subsection has a header line
  `<first_obj_num> <count>` and then exactly `count` 20-byte entries.
- Each entry format: `<10-digit-offset> <5-digit-gen> <n|f><EOL>`
  where EOL is `\r\n`, ` \r`, or ` \n` (3 variants = 20 bytes total).
- After all subsections, a `trailer` keyword + dictionary.

# `entries`

```elixir
@type entries() :: %{required({pos_integer(), non_neg_integer()}) =&gt; xref_entry()}
```

# `xref_entry`

```elixir
@type xref_entry() :: {:in_use, non_neg_integer(), non_neg_integer()} | :free
```

# `parse`

```elixir
@spec parse(binary(), non_neg_integer()) :: {:ok, entries()} | {:error, term()}
```

Parses a classic xref table starting at `offset` within `binary`.

Returns `{:ok, entries_map}` where keys are `{obj_num, gen_num}` and values
are `{:in_use, offset, gen}` or `:free`.

Returns `{:error, reason}` if the binary at that offset is not a valid
classic xref section.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
