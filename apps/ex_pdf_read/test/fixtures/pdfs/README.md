# Real-world PDF fixtures (Phase 11)

These PDFs are committed to verify reader compatibility against
PDFs produced by tools other than this library. They are NOT used
in CI by default — tagged `:fixtures` so they can be skipped.

## Inventory

| File | Source | Retrieved | License |
|------|--------|-----------|---------|
| rfc.pdf | https://www.rfc-editor.org/rfc/pdfrfc/rfc8259.txt.pdf | 2026-05-06 | IETF Trust — all IETF RFCs are freely redistributable; see https://trustee.ietf.org/license-info |
| gov.pdf | https://www.irs.gov/pub/irs-pdf/fw9.pdf | 2026-05-06 | Public domain (17 USC § 105 — U.S. government work product) |
| sample.pdf | https://www.rfc-editor.org/rfc/pdfrfc/rfc793.txt.pdf | 2026-05-06 | IETF Trust — all IETF RFCs are freely redistributable; see https://trustee.ietf.org/license-info |

### Notes

- `rfc.pdf` — RFC 8259 "The JavaScript Object Notation (JSON) Data Interchange Format" (22 KB).
  A modern text-heavy RFC; exercises text extraction on standard ASCII + Unicode content.
- `gov.pdf` — IRS Form W-9 "Request for Taxpayer Identification Number and Certification" (140 KB).
  A US government PDF form; exercises AcroForm field layout, embedded fonts, and linearization.
  As a work of the United States Government produced by the IRS, it is in the public domain.
- `sample.pdf` — RFC 793 "Transmission Control Protocol" (104 KB).
  A classic, widely-cited RFC with ASCII diagrams; exercises multi-page text extraction.

## How to update

1. Choose a small (< 200 KB) PDF from a clearly public-domain source.
2. Verify with `curl -fsSL <url> -o <file>.pdf` (exit code 0).
3. Confirm magic bytes: `head -c 5 <file>.pdf | xxd` must show `25 50 44 46 2d` (`%PDF-`).
4. Confirm size: `ls -la <file>.pdf` — must be between 1 KB and 1 MB.
5. Update this table with source URL, retrieval date, and license claim.

## Tagged execution

Run only fixture tests:

```
mix test --only fixtures
```

Skip fixture tests (default CI behaviour):

```
mix test --exclude fixtures
```
