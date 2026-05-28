# `Pdf.Reader.CID.Codespace`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/cid/codespace.ex#L1)

Variable-length codespace-aware tokenizer for predefined CMap byte sequences.

Per PDF 1.7 § 9.7.6, byte sequences are matched against codespace ranges
grouped by length (1-4 bytes). Shortest match wins. Bytes that don't
match any codespace are silently dropped one at a time.

## Spec references

- PDF 1.7 (ISO 32000-1) § 9.7.6 — Codespace ranges:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- Adobe Tech Note #5099 — CMap and CIDFont Files Specification

# `codespaces`

```elixir
@type codespaces() :: %{required(1..4) =&gt; [{non_neg_integer(), non_neg_integer()}]}
```

# `tokenize`

```elixir
@spec tokenize(binary(), codespaces()) :: [non_neg_integer()]
```

Tokenize a binary into a list of integer codes per codespace ranges.

Tries to match the shortest prefix of `bytes` against one of the codespace
ranges (by byte-length, 1 first). On a hit, appends the big-endian decoded
integer to the result and recurses on the remainder. On a miss for all
lengths 1–4, drops the first byte and recurses.

Returns `[non_neg_integer()]` (big-endian-decoded integers).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
