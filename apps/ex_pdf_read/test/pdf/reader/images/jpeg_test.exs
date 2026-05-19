defmodule Pdf.Reader.Images.JPEGTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Images.JPEG

  # ---------------------------------------------------------------------------
  # 10.1.x — JPEG passthrough + SOF marker parsing
  #
  # Spec reference: ITU-T T.81 / ISO/IEC 10918-1, § B.2.2 (SOF marker)
  # SOF markers: 0xFF 0xC0 through 0xFF 0xCF, EXCEPT 0xC4 (DHT), 0xC8 (JPG),
  # 0xCC (DAC). SOF0..SOF3, SOF5..SOF7, SOF9..SOF11, SOF13..SOF15.
  # SOF header: marker(2) + length(2) + precision(1) + height(2) + width(2) + ...
  # ---------------------------------------------------------------------------

  # Minimal SOF0 JPEG bytes for a 320×240 image.
  # Structure: SOI marker (FF D8) + APP0 (skip) + SOF0 marker
  # We construct the minimum valid SOF0 segment directly.
  #
  # SOF0 = FF C0, length = 00 11 (17 bytes), precision = 08,
  #        height = 00 F0 (240), width = 01 40 (320), components = 03
  #
  # Source: ITU-T T.81 Table B.2 — SOF segment syntax
  defp minimal_jpeg_320x240 do
    soi = <<0xFF, 0xD8>>

    # SOF0 segment: FF C0, length 17 bytes (includes length itself),
    # precision 8, height 240, width 320, 3 components
    sof0 =
      <<0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0xF0, 0x01, 0x40, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11,
        0x01, 0x03, 0x11, 0x01>>

    # EOI
    eoi = <<0xFF, 0xD9>>

    soi <> sof0 <> eoi
  end

  # SOF2 (progressive) = FF C2 — also a valid SOF marker
  defp minimal_jpeg_progressive_100x200 do
    soi = <<0xFF, 0xD8>>

    # SOF2: 0xFF 0xC2, height=200 (0x00C8), width=100 (0x0064)
    sof2 =
      <<0xFF, 0xC2, 0x00, 0x11, 0x08, 0x00, 0xC8, 0x00, 0x64, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11,
        0x01, 0x03, 0x11, 0x01>>

    eoi = <<0xFF, 0xD9>>
    soi <> sof2 <> eoi
  end

  # A jpeg with a DHT (0xFF 0xC4) marker before the SOF0 — DHT must be skipped
  defp minimal_jpeg_with_dht_before_sof do
    soi = <<0xFF, 0xD8>>

    # DHT marker: FF C4, must be skipped (not a SOF)
    # JPEG length field = 2 (for itself) + payload bytes.
    # We use 20 bytes of dummy payload → length = 22 (0x0016)
    dht_payload_size = 20
    dht_total_length = dht_payload_size + 2
    dht_payload = :binary.copy(<<0x00>>, dht_payload_size)
    # marker (2 bytes) + length (2 bytes big-endian) + payload
    dht = <<0xFF, 0xC4, dht_total_length::16>> <> dht_payload

    # SOF0 for 50x80 image (height=80=0x0050, width=50=0x0032)
    sof0 =
      <<0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x50, 0x00, 0x32, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11,
        0x01, 0x03, 0x11, 0x01>>

    eoi = <<0xFF, 0xD9>>
    soi <> dht <> sof0 <> eoi
  end

  # ---------------------------------------------------------------------------
  # Tests — 10.1.1, 10.1.2, 10.1.3
  # ---------------------------------------------------------------------------

  describe "JPEG.dimensions/1" do
    # 10.1.1 — parses SOF0 to get {height, width}
    test "returns {height, width} from SOF0 marker in a minimal JPEG" do
      jpeg = minimal_jpeg_320x240()
      assert {:ok, %{height: 240, width: 320}} = JPEG.dimensions(jpeg)
    end

    # 10.1.2 — parses SOF2 (progressive)
    test "returns dimensions from a SOF2 (progressive) JPEG" do
      jpeg = minimal_jpeg_progressive_100x200()
      assert {:ok, %{height: 200, width: 100}} = JPEG.dimensions(jpeg)
    end

    # 10.1.3 — skips DHT (0xFF 0xC4) marker before SOF
    test "skips non-SOF markers (DHT) and finds SOF0" do
      jpeg = minimal_jpeg_with_dht_before_sof()
      assert {:ok, %{height: 80, width: 50}} = JPEG.dimensions(jpeg)
    end

    # 10.1.4 — empty binary returns error
    test "returns error for empty binary" do
      assert {:error, _} = JPEG.dimensions(<<>>)
    end

    # error case: binary without SOF marker
    test "returns error when no SOF marker found" do
      # Only SOI + EOI — no SOF
      jpeg = <<0xFF, 0xD8, 0xFF, 0xD9>>
      assert {:error, _} = JPEG.dimensions(jpeg)
    end
  end
end
