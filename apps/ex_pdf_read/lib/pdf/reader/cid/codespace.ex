defmodule Pdf.Reader.CID.Codespace do
  @moduledoc """
  Variable-length codespace-aware tokenizer for predefined CMap byte sequences.

  Per PDF 1.7 § 9.7.6, byte sequences are matched against codespace ranges
  grouped by length (1-4 bytes). Shortest match wins. Bytes that don't
  match any codespace are silently dropped one at a time.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 9.7.6 — Codespace ranges:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - Adobe Tech Note #5099 — CMap and CIDFont Files Specification
  """

  @type codespaces :: %{(1..4) => [{non_neg_integer(), non_neg_integer()}]}

  @doc """
  Tokenize a binary into a list of integer codes per codespace ranges.

  Tries to match the shortest prefix of `bytes` against one of the codespace
  ranges (by byte-length, 1 first). On a hit, appends the big-endian decoded
  integer to the result and recurses on the remainder. On a miss for all
  lengths 1–4, drops the first byte and recurses.

  Returns `[non_neg_integer()]` (big-endian-decoded integers).
  """
  @spec tokenize(binary(), codespaces()) :: [non_neg_integer()]
  def tokenize(<<>>, _codespaces), do: []

  def tokenize(bytes, codespaces) do
    case match_shortest(bytes, codespaces, 1) do
      {:ok, code, rest} ->
        [code | tokenize(rest, codespaces)]

      :nomatch ->
        <<_dropped::8, rest::binary>> = bytes
        tokenize(rest, codespaces)
    end
  end

  # Try matching the shortest prefix of `bytes` against codespace ranges of
  # the given `length`. Increments length on miss, stops at 4.
  defp match_shortest(_bytes, _codespaces, length) when length > 4, do: :nomatch

  defp match_shortest(bytes, codespaces, length) when byte_size(bytes) < length do
    match_shortest(bytes, codespaces, length + 1)
  end

  defp match_shortest(bytes, codespaces, length) do
    <<chunk::binary-size(length), rest::binary>> = bytes
    code = :binary.decode_unsigned(chunk)
    ranges = Map.get(codespaces, length, [])

    if Enum.any?(ranges, fn {lo, hi} -> code >= lo and code <= hi end) do
      {:ok, code, rest}
    else
      match_shortest(bytes, codespaces, length + 1)
    end
  end
end
