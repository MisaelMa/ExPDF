defmodule Pdf.Reader.Filter.FlateTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Filter.Flate

  # Helper: compress a binary using zlib
  defp compress(data) do
    z = :zlib.open()
    :zlib.deflateInit(z, :default)
    compressed = :zlib.deflate(z, data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)
    IO.iodata_to_binary(compressed)
  end

  describe "decode/2 — basic inflate (task 2.1.1)" do
    test "round-trips a small synthetic binary" do
      original = "Hello, PDF world!"
      compressed = compress(original)
      assert {:ok, ^original} = Flate.decode(compressed, %{})
    end

    test "round-trips binary data (non-text)" do
      original = <<0, 1, 2, 3, 4, 5, 255, 254, 253>>
      compressed = compress(original)
      assert {:ok, ^original} = Flate.decode(compressed, %{})
    end

    test "returns error for invalid zlib data" do
      assert {:error, _} = Flate.decode(<<1, 2, 3, 4>>, %{})
    end
  end

  describe "decode/2 — PNG predictor (task 2.1.3)" do
    # PNG predictor: each row is prefixed with a filter-type byte.
    # Predictor 12 = Up (each byte is delta from byte above).
    # For a 2-row image, Columns=4, Colors=1, BPC=8:
    #   Row 1: type=0 (None), data [10, 20, 30, 40]
    #   Row 2: type=2 (Up),   data [1, 2, 3, 4]  (deltas from row above)
    # Expected output: [10,20,30,40,  11,22,33,44]
    test "PNG predictor Up (type 2, Predictor 12) undone correctly" do
      # Build raw pre-predictor rows
      raw_rows = <<0, 10, 20, 30, 40, 2, 1, 2, 3, 4>>
      compressed = compress(raw_rows)

      params = %{"Predictor" => 12, "Columns" => 4, "Colors" => 1, "BitsPerComponent" => 8}
      assert {:ok, result} = Flate.decode(compressed, params)
      assert result == <<10, 20, 30, 40, 11, 22, 33, 44>>
    end

    test "PNG predictor None (type 0) passes data through unchanged" do
      raw_rows = <<0, 10, 20, 30, 40>>
      compressed = compress(raw_rows)

      params = %{"Predictor" => 10, "Columns" => 4, "Colors" => 1, "BitsPerComponent" => 8}
      assert {:ok, result} = Flate.decode(compressed, params)
      assert result == <<10, 20, 30, 40>>
    end
  end

  describe "decode/2 — TIFF Predictor 2 (task 2.1.5)" do
    # TIFF Predictor 2 (horizontal differencing):
    # Input row: [10, 5, 3, 2] (each byte is a delta from the previous)
    # Output row: [10, 15, 18, 20]
    test "TIFF Predictor 2 undone correctly for 1-component 8-bit image" do
      # Single row, Columns=4, Colors=1, BPC=8
      raw_row = <<10, 5, 3, 2>>
      compressed = compress(raw_row)

      params = %{"Predictor" => 2, "Columns" => 4, "Colors" => 1, "BitsPerComponent" => 8}
      assert {:ok, result} = Flate.decode(compressed, params)
      assert result == <<10, 15, 18, 20>>
    end

    test "TIFF Predictor 2 handles multiple rows" do
      # Two rows of 3 bytes each
      # Row 1 encoded: [5, 2, 1] → decoded: [5, 7, 8]
      # Row 2 encoded: [10, 0, 3] → decoded: [10, 10, 13]
      raw = <<5, 2, 1, 10, 0, 3>>
      compressed = compress(raw)

      params = %{"Predictor" => 2, "Columns" => 3, "Colors" => 1, "BitsPerComponent" => 8}
      assert {:ok, result} = Flate.decode(compressed, params)
      assert result == <<5, 7, 8, 10, 10, 13>>
    end
  end
end
