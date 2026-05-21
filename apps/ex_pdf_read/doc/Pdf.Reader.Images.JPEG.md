# `Pdf.Reader.Images.JPEG`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/images/jpeg.ex#L1)

JPEG (DCTDecode) image utilities for `Pdf.Reader`.

## SOF marker parsing

Reads JPEG dimensions from the Start-of-Frame (SOF) marker without fully
decoding the JPEG. This is a read-only scan used to populate `%Pdf.Reader.Image{}`
width and height from the DCT-encoded bytes.

### SOF marker table

Source: ITU-T T.81 / ISO/IEC 10918-1, § B.1.1.3 (marker syntax), Table B.1.

Valid SOF markers (0xFF 0xCy):

| Marker byte | Name  | Notes |
|-------------|-------|-------|
| 0xC0        | SOF0  | Baseline DCT |
| 0xC1        | SOF1  | Extended sequential DCT |
| 0xC2        | SOF2  | Progressive DCT |
| 0xC3        | SOF3  | Lossless (sequential) |
| 0xC5        | SOF5  | Differential sequential DCT |
| 0xC6        | SOF6  | Differential progressive DCT |
| 0xC7        | SOF7  | Differential lossless (sequential) |
| 0xC9        | SOF9  | Extended sequential DCT (arithmetic) |
| 0xCA        | SOF10 | Progressive DCT (arithmetic) |
| 0xCB        | SOF11 | Lossless (arithmetic) |
| 0xCD        | SOF13 | Differential sequential DCT (arithmetic) |
| 0xCE        | SOF14 | Differential progressive DCT (arithmetic) |
| 0xCF        | SOF15 | Differential lossless (arithmetic) |

Non-SOF markers to skip:
| 0xC4 | DHT | Huffman table |
| 0xC8 | JPG | JPEG extensions |
| 0xCC | DAC | Arithmetic coding conditioning |

### SOF segment layout (ITU-T T.81 § B.2.2)

    0xFF 0xCy   — marker (2 bytes)
    Ls          — segment length in bytes, big-endian uint16 (includes itself, not the marker)
    P           — sample precision (1 byte)
    Y           — number of lines / height (2 bytes, big-endian)
    X           — number of samples per line / width (2 bytes, big-endian)
    Nf          — number of components (1 byte)
    ... (Nf × 3 bytes of component spec — not read here)

`dimensions/1` returns `{:ok, %{height: y, width: x}}` on success.

# `dimensions`

```elixir
@spec dimensions(binary()) ::
  {:ok, %{height: non_neg_integer(), width: non_neg_integer()}}
  | {:error, atom()}
```

Scans a JPEG binary for a SOF marker and extracts height and width.

Returns `{:ok, %{height: integer, width: integer}}` on success.
Returns `{:error, :no_sof_marker}` if no SOF marker is found.
Returns `{:error, :not_a_jpeg}` if the binary does not start with the JPEG SOI marker.

Source: ITU-T T.81 / ISO/IEC 10918-1, § B.2.2.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
