defmodule Pdf.Reader.Images.JPEG do
  @moduledoc """
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
  """

  @doc """
  Scans a JPEG binary for a SOF marker and extracts height and width.

  Returns `{:ok, %{height: integer, width: integer}}` on success.
  Returns `{:error, :no_sof_marker}` if no SOF marker is found.
  Returns `{:error, :not_a_jpeg}` if the binary does not start with the JPEG SOI marker.

  Source: ITU-T T.81 / ISO/IEC 10918-1, § B.2.2.
  """
  @spec dimensions(binary()) ::
          {:ok, %{height: non_neg_integer(), width: non_neg_integer()}} | {:error, atom()}
  def dimensions(<<>>) do
    {:error, :not_a_jpeg}
  end

  def dimensions(<<0xFF, 0xD8, rest::binary>>) do
    scan_markers(rest)
  end

  def dimensions(_other) do
    {:error, :not_a_jpeg}
  end

  # ---------------------------------------------------------------------------
  # Internal — marker scanner
  # ---------------------------------------------------------------------------

  # Walk JPEG markers one by one until we find a SOF or exhaust the binary.
  # Each marker is: 0xFF <type> [<length_big_endian_16> <payload...>]
  # Markers without a length field (standalone markers): SOI (D8), EOI (D9),
  # RST0..RST7 (D0..D7), TEM (01). All other markers have a length field.
  defp scan_markers(<<>>) do
    {:error, :no_sof_marker}
  end

  # Consume padding 0xFF bytes
  defp scan_markers(<<0xFF, 0xFF, rest::binary>>) do
    scan_markers(<<0xFF, rest::binary>>)
  end

  # SOI marker (D8) — no length, continue
  defp scan_markers(<<0xFF, 0xD8, rest::binary>>) do
    scan_markers(rest)
  end

  # EOI marker (D9) — end of image, SOF not found
  defp scan_markers(<<0xFF, 0xD9, _rest::binary>>) do
    {:error, :no_sof_marker}
  end

  # RST markers (D0..D7) — no length
  defp scan_markers(<<0xFF, rst, rest::binary>>) when rst >= 0xD0 and rst <= 0xD7 do
    scan_markers(rest)
  end

  # TEM marker (01) — no length
  defp scan_markers(<<0xFF, 0x01, rest::binary>>) do
    scan_markers(rest)
  end

  # SOF marker (C0..CF except C4, C8, CC) — parse dimensions
  defp scan_markers(
         <<0xFF, sof, length_hi, length_lo, 0x08, height_hi, height_lo, width_hi, width_lo,
           _rest::binary>>
       )
       when sof in [
              0xC0,
              0xC1,
              0xC2,
              0xC3,
              0xC5,
              0xC6,
              0xC7,
              0xC9,
              0xCA,
              0xCB,
              0xCD,
              0xCE,
              0xCF
            ] do
    _length = length_hi * 256 + length_lo
    height = height_hi * 256 + height_lo
    width = width_hi * 256 + width_lo
    {:ok, %{height: height, width: width}}
  end

  # SOF marker with non-8-bit precision — still return dimensions
  defp scan_markers(
         <<0xFF, sof, length_hi, length_lo, _precision, height_hi, height_lo, width_hi, width_lo,
           _rest::binary>>
       )
       when sof in [
              0xC0,
              0xC1,
              0xC2,
              0xC3,
              0xC5,
              0xC6,
              0xC7,
              0xC9,
              0xCA,
              0xCB,
              0xCD,
              0xCE,
              0xCF
            ] do
    _length = length_hi * 256 + length_lo
    height = height_hi * 256 + height_lo
    width = width_hi * 256 + width_lo
    {:ok, %{height: height, width: width}}
  end

  # Any other marker with length field — skip it and continue
  defp scan_markers(<<0xFF, marker, length_hi, length_lo, rest::binary>>)
       when marker not in [0xD8, 0xD9, 0x01] and not (marker >= 0xD0 and marker <= 0xD7) do
    # Length includes the 2 length bytes but not the marker bytes
    # So payload size = length - 2
    payload_size = length_hi * 256 + length_lo - 2

    if payload_size >= 0 and byte_size(rest) >= payload_size do
      after_segment = binary_part(rest, payload_size, byte_size(rest) - payload_size)
      scan_markers(after_segment)
    else
      {:error, :truncated_jpeg}
    end
  end

  # Not enough bytes or unknown structure
  defp scan_markers(_) do
    {:error, :no_sof_marker}
  end
end
