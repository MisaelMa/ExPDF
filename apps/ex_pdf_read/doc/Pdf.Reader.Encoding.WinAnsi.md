# `Pdf.Reader.Encoding.WinAnsi`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/encoding/win_ansi.ex#L1)

WinAnsi (Windows-1252 / CP1252) encoding — read direction.

Delegates to the existing `Pdf.Encoding.WinAnsi` writer module for the
underlying character table data, exposing a single `decode/1` function
that maps a byte (0–255) to its Unicode codepoint.

Used by the reader when a font specifies /Encoding /WinAnsiEncoding or
derives encoding from a Windows-origin Type 1 or TrueType font.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
