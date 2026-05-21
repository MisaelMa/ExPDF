# `ExQR.GaloisField`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_qr/galois_field.ex#L1)

GF(256) arithmetic for QR Code Reed-Solomon error correction.

Uses the primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (0x11D)
with generator α = 2. Exp and log tables are precomputed at compile time.

# `exp`

Returns α^n in GF(256).

# `generator_polynomial`

Generate a Reed-Solomon generator polynomial of given degree.

# `log`

Returns log_α(n) in GF(256). n must be > 0.

# `multiply`

Multiply two values in GF(256).

# `multiply_polynomials`

Multiply two polynomials over GF(256).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
