defmodule Pdf.Reader.Filter.Flate do
  @moduledoc """
  FlateDecode filter — zlib inflate, with optional PNG and TIFF predictor
  un-filtering.

  ## Predictor support

  Predictor values in `/DecodeParms`:
  - `1` (default) — no predictor.
  - `2` — TIFF Predictor 2 (horizontal differencing), applied row-by-row.
  - `10` — PNG None (row type 0 prefix consumed and discarded).
  - `11` — PNG Sub.
  - `12` — PNG Up.
  - `13` — PNG Average.
  - `14` — PNG Paeth.
  - `15` — PNG Optimal (decoder treats row-type byte as the actual filter; this is
    the same as having per-row filter selection — just read the type byte per row).

  ## DecodeParms keys

  | Key                | Default | Meaning                                    |
  |--------------------|---------|--------------------------------------------|
  | `"Predictor"`      | `1`     | Predictor type (1 = none)                  |
  | `"Columns"`        | `1`     | Row width in samples                       |
  | `"Colors"`         | `1`     | Number of color components per sample      |
  | `"BitsPerComponent"` | `8`  | Bits per component                         |
  """

  @behaviour Pdf.Reader.Filter

  @doc """
  Inflate a zlib-compressed binary, then apply any configured predictor.
  """
  @spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def decode(bytes, params) do
    case inflate(bytes) do
      {:ok, inflated} -> apply_predictor(inflated, params)
      {:error, _} = err -> err
    end
  end

  # --- zlib inflate ---

  defp inflate(bytes) do
    z = :zlib.open()

    result =
      try do
        :zlib.inflateInit(z)
        chunks = :zlib.inflate(z, bytes)
        :zlib.inflateEnd(z)
        {:ok, IO.iodata_to_binary(chunks)}
      catch
        :error, reason -> {:error, {:flate_decode_error, reason}}
      end

    :zlib.close(z)
    result
  end

  # --- Predictor dispatch ---

  defp apply_predictor(data, params) do
    predictor = Map.get(params, "Predictor", 1)
    columns = Map.get(params, "Columns", 1)
    colors = Map.get(params, "Colors", 1)
    bpc = Map.get(params, "BitsPerComponent", 8)

    cond do
      predictor == 1 -> {:ok, data}
      predictor == 2 -> tiff_predictor2(data, columns, colors, bpc)
      predictor in 10..15 -> png_predictor(data, columns, colors, bpc)
      true -> {:error, {:flate_decode_error, {:unsupported_predictor, predictor}}}
    end
  end

  # --- TIFF Predictor 2 (horizontal differencing) ---

  defp tiff_predictor2(data, columns, colors, bpc) do
    bytes_per_row = div(columns * colors * bpc + 7, 8)
    undo_tiff_rows(data, bytes_per_row, <<>>)
  end

  defp undo_tiff_rows(<<>>, _stride, acc), do: {:ok, acc}

  defp undo_tiff_rows(data, stride, acc) do
    case data do
      <<row::binary-size(stride), rest::binary>> ->
        undone = undo_tiff_row(row, <<>>, 0)
        undo_tiff_rows(rest, stride, acc <> undone)

      _ ->
        {:error, {:flate_decode_error, :tiff_predictor_truncated}}
    end
  end

  # Reconstruct each byte as: current_delta + previous_value (mod 256)
  defp undo_tiff_row(<<>>, acc, _prev), do: acc

  defp undo_tiff_row(<<byte, rest::binary>>, acc, prev) do
    value = rem(byte + prev, 256)
    undo_tiff_row(rest, acc <> <<value>>, value)
  end

  # --- PNG predictors (10–15) ---

  defp png_predictor(data, columns, colors, bpc) do
    bytes_per_row = div(columns * colors * bpc + 7, 8)
    # stride includes the 1-byte filter-type prefix
    row_stride = bytes_per_row + 1
    prev_row = :binary.copy(<<0>>, bytes_per_row)
    undo_png_rows(data, row_stride, bytes_per_row, prev_row, <<>>)
  end

  defp undo_png_rows(<<>>, _stride, _width, _prev, acc), do: {:ok, acc}

  defp undo_png_rows(data, stride, width, prev_row, acc) do
    case data do
      <<filter_type, row_data::binary-size(width), rest::binary>> ->
        case undo_png_row(filter_type, row_data, prev_row) do
          {:ok, undone} ->
            undo_png_rows(rest, stride, width, undone, acc <> undone)

          {:error, _} = err ->
            err
        end

      _ ->
        {:error, {:flate_decode_error, :png_predictor_truncated}}
    end
  end

  # PNG filter type 0: None — pass through
  defp undo_png_row(0, row, _prev), do: {:ok, row}

  # PNG filter type 1: Sub — each byte is delta from left neighbor
  defp undo_png_row(1, row, _prev) do
    {:ok, undo_sub(row, <<>>, 0)}
  end

  # PNG filter type 2: Up — each byte is delta from byte in row above
  defp undo_png_row(2, row, prev) do
    result =
      Enum.zip(:binary.bin_to_list(row), :binary.bin_to_list(prev))
      |> Enum.reduce(<<>>, fn {r, p}, acc ->
        acc <> <<rem(r + p, 256)>>
      end)

    {:ok, result}
  end

  # PNG filter type 3: Average — delta from average of left and above
  defp undo_png_row(3, row, prev) do
    row_list = :binary.bin_to_list(row)
    prev_list = :binary.bin_to_list(prev)

    {result, _} =
      Enum.zip(row_list, prev_list)
      |> Enum.reduce({<<>>, 0}, fn {r, p}, {acc, left} ->
        avg = div(left + p, 2)
        value = rem(r + avg, 256)
        {acc <> <<value>>, value}
      end)

    {:ok, result}
  end

  # PNG filter type 4: Paeth predictor
  defp undo_png_row(4, row, prev) do
    row_list = :binary.bin_to_list(row)
    prev_list = :binary.bin_to_list(prev)

    {result, _} =
      Enum.zip(row_list, prev_list)
      |> Enum.reduce({<<>>, {0, 0}}, fn {r, p}, {acc, {left, prev_left}} ->
        predictor = paeth(left, p, prev_left)
        value = rem(r + predictor, 256)
        {acc <> <<value>>, {value, p}}
      end)

    {:ok, result}
  end

  defp undo_png_row(type, _row, _prev) do
    {:error, {:flate_decode_error, {:unsupported_png_filter_type, type}}}
  end

  # Helper for Sub filter type
  defp undo_sub(<<>>, acc, _left), do: acc

  defp undo_sub(<<b, rest::binary>>, acc, left) do
    value = rem(b + left, 256)
    undo_sub(rest, acc <> <<value>>, value)
  end

  # Paeth predictor function (PNG spec)
  defp paeth(a, b, c) do
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)

    cond do
      pa <= pb and pa <= pc -> a
      pb <= pc -> b
      true -> c
    end
  end
end
