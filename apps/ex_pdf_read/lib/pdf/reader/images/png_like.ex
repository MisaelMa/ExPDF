defmodule Pdf.Reader.Images.PNGLike do
  @moduledoc """
  PNG-like image decoding for `Pdf.Reader`.

  Handles PDF Image XObjects with `/Filter /FlateDecode` and optional
  `/DecodeParms` predictor. After Flate inflation (via `:zlib`) and
  predictor un-filtering, the result is raw pixel data.

  ## API

      decode(stream_bytes, params) :: {:ok, raw_pixels} | {:error, reason}

  `stream_bytes` is the raw (still compressed) XObject stream body.
  `params` is the XObject dictionary (or its `/DecodeParms` sub-dict) and
  should contain:
  - `"Width"` (integer)
  - `"Height"` (integer)
  - `"BitsPerComponent"` (integer, default 8)
  - `"ColorSpace"` (name or nil — used to infer number of color components)
  - `"Colors"` (integer, default inferred from ColorSpace or 1)
  - `"Predictor"` (integer, default 1 = no predictor)
  - `"Columns"` (integer, default = Width)

  ## Spec reference

  PDF 1.7 § 7.4.4.4 (FlateDecode filter), § 7.4.4.3 (PNG predictor).
  Delegates to `Pdf.Reader.Filter.Flate.decode/2` for the combined inflate +
  predictor step — the Flate filter implementation already handles PNG
  predictors 10–15 per batch 2.
  """

  alias Pdf.Reader.Filter.Flate

  @doc """
  Decodes a FlateDecode-encoded image stream to raw pixel data.

  Builds a `DecodeParms` map from the XObject dict and delegates to
  `Pdf.Reader.Filter.Flate.decode/2`, which handles both inflation and
  PNG predictor un-filtering.

  Returns `{:ok, raw_pixel_bytes}` or `{:error, reason}`.
  """
  @spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def decode(stream_bytes, params) when is_binary(stream_bytes) and is_map(params) do
    # Build the DecodeParms map that Flate.decode/2 expects.
    # If the XObject dict has its own Predictor/Columns/Colors/BitsPerComponent,
    # pass them through. Otherwise use defaults.
    decode_parms = build_decode_parms(params)
    Flate.decode(stream_bytes, decode_parms)
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  defp build_decode_parms(params) do
    predictor = Map.get(params, "Predictor", 1)
    columns = Map.get(params, "Columns") || Map.get(params, "Width", 1)
    bpc = Map.get(params, "BitsPerComponent", 8)
    colors = Map.get(params, "Colors") || infer_colors(params)

    %{
      "Predictor" => predictor,
      "Columns" => columns,
      "BitsPerComponent" => bpc,
      "Colors" => colors
    }
  end

  # Infer the number of color components from the ColorSpace entry.
  # Spec reference: PDF 1.7 § 8.6 (Color spaces).
  defp infer_colors(%{"Colors" => n}) when is_integer(n), do: n

  defp infer_colors(%{"ColorSpace" => cs}) do
    case cs do
      {:name, "DeviceRGB"} -> 3
      {:name, "DeviceCMYK"} -> 4
      {:name, "DeviceGray"} -> 1
      {:name, "CalRGB"} -> 3
      {:name, "CalGray"} -> 1
      "DeviceRGB" -> 3
      "DeviceCMYK" -> 4
      "DeviceGray" -> 1
      # Default: assume grayscale
      _ -> 1
    end
  end

  defp infer_colors(_), do: 1
end
