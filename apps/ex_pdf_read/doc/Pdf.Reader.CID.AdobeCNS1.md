# `Pdf.Reader.CID.AdobeCNS1`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/cid/adobe_cns1.ex#L1)

Adobe-CNS1 CID to Unicode mapping (~18000 entries).

Bundled at compile time from `priv/adobe-cns1-cid2unicode.txt`,
normalized from the `cid2code.txt` table in the `cmap-resources` repository
(Adobe-CNS1-7/cid2code.txt, UniCNS-UCS2 column).

Each entry generates a pattern-match clause (O(1) BEAM dispatch).

## Spec references

- PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts:
  https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
- PDF 1.7 § 9.7.4 — CIDFonts
- PDF 1.7 § 9.7.5 — CMaps (Identity-H, Identity-V predefined)
- Adobe-CNS1 collection: https://github.com/adobe-type-tools/Adobe-CNS1
- CMap resources (source data): https://github.com/adobe-type-tools/cmap-resources

# `lookup`

```elixir
@spec lookup(non_neg_integer()) :: {:ok, non_neg_integer()} | :error
```

Returns `{:ok, codepoint}` for known CIDs, `:error` for unknown ones.

Codepoint is a Unicode scalar value (non_neg_integer).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
