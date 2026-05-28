# `Pdf.Reader.Error`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.2/lib/pdf/reader/error.ex#L1)

Exception raised by bang variants of `Pdf.Reader` functions.

The `:reason` field carries the same atom or tagged tuple that the
non-bang variant would have returned in `{:error, reason}`.

Do not rescue this in production pipelines — use the non-bang forms
and pattern-match on `{:error, reason}` instead.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
