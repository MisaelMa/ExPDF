defmodule Pdf.Reader.Images.PNGLikeTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Images.PNGLike

  # ---------------------------------------------------------------------------
  # 10.2.x — PNG-like image decoding (FlateDecode + predictor)
  #
  # Spec reference: PDF 1.7 § 7.4.4.4 (LZW and FlateDecode)
  # PDF image XObjects with FlateDecode filter and optional DecodeParms predictor.
  # Width, height, BitsPerComponent are in the XObject dictionary.
  # After Flate+predictor, the result is raw pixel data.
  # ---------------------------------------------------------------------------

  # Build raw pixel data for a 2×2 RGB image (no predictor)
  # 2 rows × 2 pixels × 3 bytes/pixel = 12 bytes total
  defp raw_2x2_rgb do
    # Row 1: red (255,0,0), green (0,255,0)
    # Row 2: blue (0,0,255), white (255,255,255)
    <<255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255>>
  end

  # Compress raw pixel data with :zlib (no predictor)
  defp compress_raw(data) do
    :zlib.compress(data)
  end

  # Build params for a 2×2 RGB image (no predictor, Predictor = 1 = default)
  defp params_2x2_rgb_no_predictor do
    %{"Width" => 2, "Height" => 2, "BitsPerComponent" => 8, "ColorSpace" => {:name, "DeviceRGB"}}
  end

  # Build a FlateDecode stream with PNG Up predictor (Predictor 12)
  # for a 2×2 RGB image.
  # With PNG Up predictor, each row is prefixed with a filter byte.
  # Filter type 2 (Up) = each byte = pixel_byte - above_byte (mod 256).
  # First row Up-filtered: all pixels treated as above=0, so filtered = raw.
  # Each row: 1 filter byte + 6 pixel bytes
  defp png_up_encoded_2x2 do
    raw = raw_2x2_rgb()

    # Row 1 (6 bytes): 255 0 0 0 255 0 → Up filter: each - 0 = same
    row1_filter_byte = 2
    row1_data = binary_part(raw, 0, 6)
    row1 = <<row1_filter_byte>> <> row1_data

    # Row 2 (6 bytes): 0 0 255 255 255 255 → Up: each - row1_byte
    row2_filter_byte = 2
    row2_raw = binary_part(raw, 6, 6)

    row2_filtered =
      for i <- 0..5 do
        r2 = :binary.at(row2_raw, i)
        r1 = :binary.at(row1_data, i)
        rem(r2 - r1 + 256, 256)
      end
      |> IO.iodata_to_binary()

    row2 = <<row2_filter_byte>> <> row2_filtered

    predictored = row1 <> row2
    :zlib.compress(predictored)
  end

  # ---------------------------------------------------------------------------
  # Tests — 10.2.1, 10.2.2, 10.2.3
  # ---------------------------------------------------------------------------

  describe "PNGLike.decode/2" do
    # 10.2.1 — decodes a FlateDecode stream without predictor
    test "decodes a FlateDecode stream with no predictor (Predictor=1)" do
      raw = raw_2x2_rgb()
      compressed = compress_raw(raw)
      params = params_2x2_rgb_no_predictor()

      assert {:ok, decoded} = PNGLike.decode(compressed, params)
      assert decoded == raw
    end

    # 10.2.2 — decodes a FlateDecode stream with PNG Up predictor
    test "decodes a FlateDecode stream with PNG Up predictor (Predictor=12)" do
      raw = raw_2x2_rgb()
      encoded = png_up_encoded_2x2()

      params = %{
        "Width" => 2,
        "Height" => 2,
        "BitsPerComponent" => 8,
        "ColorSpace" => {:name, "DeviceRGB"},
        "Predictor" => 12,
        "Columns" => 2,
        "Colors" => 3
      }

      assert {:ok, decoded} = PNGLike.decode(encoded, params)
      assert decoded == raw
    end

    # 10.2.3 — returns error on corrupted compressed data
    test "returns error on corrupted FlateDecode stream" do
      params = %{"Width" => 2, "Height" => 2, "BitsPerComponent" => 8}
      assert {:error, _} = PNGLike.decode(<<1, 2, 3, 4, 5>>, params)
    end
  end
end
