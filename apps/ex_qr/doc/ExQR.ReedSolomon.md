# `ExQR.ReedSolomon`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_qr/reed_solomon.ex#L1)

Reed-Solomon error correction encoding for QR codes.

Computes error correction codewords for a given data block
using polynomial division over GF(256).

# `encode`

Compute error correction codewords for a data block.

## Parameters
  - `data` — list of data codeword integers (0–255)
  - `ec_count` — number of error correction codewords to generate

## Returns
  List of `ec_count` error correction codeword integers.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
