# `ExQR.Encode`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_qr/encode.ex#L1)

QR Code data encoding: mode selection, bit stream construction,
error correction block interleaving, and final codeword sequence.

# `encode`

Encode text into the final codeword sequence (data + EC, interleaved).

Returns `{:ok, version, codewords}` or `{:error, reason}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
