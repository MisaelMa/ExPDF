# `ExQR.Matrix`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_qr/matrix.ex#L1)

QR Code matrix construction: function patterns, data placement,
masking, and format information.

The matrix is represented as a map of `{row, col} => value`
where value is 0 (white) or 1 (black).

# `build`

Build the final QR matrix for a given version, EC level, and codewords.

Returns a `size × size` matrix as a map of `{row, col} => 0 | 1`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
