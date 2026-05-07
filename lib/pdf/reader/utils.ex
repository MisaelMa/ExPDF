defmodule Pdf.Reader.Utils do
  @moduledoc """
  Shared utility helpers for `Pdf.Reader` sub-modules.

  Provides string decoding and rectangle parsing used by AcroForm, Outlines,
  Annotations, and Destination modules.

  ## Spec references

  - PDF 1.7 § 7.9.2.2 — Text String Type (UTF-16BE BOM):
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  """

  # ---------------------------------------------------------------------------
  # decode_pdf_string/1
  # PDF 1.7 § 7.9.2.2 — Text String Type
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a PDF string value to a UTF-8 `String.t()`.

  Handles the following input variants:

  - `nil` → `nil`
  - non-binary, non-tuple → `nil`
  - `{:string, binary}` tuple — unwraps and decodes the binary
  - `<<0xFE, 0xFF, ...>>` — UTF-16BE BOM prefix → decoded to UTF-8 via `:unicode`
  - plain binary — if valid UTF-8, returned as-is; otherwise best-effort ASCII
    extraction (non-ASCII bytes replaced with `"?"`)

  ## Spec reference

  PDF 1.7 § 7.9.2.2 — Text String Type (UTF-16BE BOM).
  """
  @spec decode_pdf_string(any()) :: String.t() | nil
  def decode_pdf_string(nil), do: nil

  # Unwrap {:string, binary} tuples — common in parser output
  def decode_pdf_string({:string, binary}) when is_binary(binary) do
    decode_pdf_string(binary)
  end

  # Unwrap {:hex_string, binary} tuples — hex-encoded PDF strings (e.g. <FEFF...> syntax)
  def decode_pdf_string({:hex_string, binary}) when is_binary(binary) do
    decode_pdf_string(binary)
  end

  # UTF-16BE BOM: 0xFE 0xFF prefix
  def decode_pdf_string(<<0xFE, 0xFF, rest::binary>>) do
    case :unicode.characters_to_binary(rest, {:utf16, :big}, :utf8) do
      result when is_binary(result) -> result
      _ -> rest
    end
  end

  # Plain binary — valid UTF-8 or best-effort ASCII
  def decode_pdf_string(binary) when is_binary(binary) do
    if String.valid?(binary) do
      binary
    else
      # Best-effort: preserve ASCII bytes, replace non-ASCII with "?"
      for <<b <- binary>>, into: "", do: if(b < 128, do: <<b>>, else: "?")
    end
  end

  # Non-binary, non-tuple terms
  def decode_pdf_string(_), do: nil

  # ---------------------------------------------------------------------------
  # parse_rect/1
  # PDF 1.7 § 8.4.5 — Rectangles
  # ---------------------------------------------------------------------------

  @doc """
  Parses a PDF `/Rect` array into a `{x1, y1, x2, y2}` tuple of floats.

  Returns `nil` for any input that is not a 4-element list of numbers.

  ## Examples

      iex> Pdf.Reader.Utils.parse_rect([0, 0, 100, 200])
      {0.0, 0.0, 100.0, 200.0}

      iex> Pdf.Reader.Utils.parse_rect(nil)
      nil
  """
  @spec parse_rect(any()) :: {number(), number(), number(), number()} | nil
  def parse_rect([x1, y1, x2, y2])
      when is_number(x1) and is_number(y1) and is_number(x2) and is_number(y2) do
    {x1 * 1.0, y1 * 1.0, x2 * 1.0, y2 * 1.0}
  end

  def parse_rect(_), do: nil
end
