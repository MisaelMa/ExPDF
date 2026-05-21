# `ExQR.Tables`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v0.1.0/lib/ex_qr/tables.ex#L1)

QR Code version tables: data capacity, EC block structure,
alignment pattern positions, and format/version information.

# `alignment_positions`

Alignment pattern center coordinates for a version.

# `char_count_bits`

Character count indicator bit length for byte mode.

# `data_capacity`

Total data codewords capacity for version and EC level.

# `ec_info`

Get EC block structure for version and level.

# `format_info`

Get the 15-bit format information value.

# `min_version`

Find the smallest version that can hold `byte_count` bytes at `level`.

# `size`

QR code size in modules for a given version.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
