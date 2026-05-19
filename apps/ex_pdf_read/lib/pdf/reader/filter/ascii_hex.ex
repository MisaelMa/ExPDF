defmodule Pdf.Reader.Filter.ASCIIHex do
  @moduledoc """
  ASCIIHexDecode filter — decodes a sequence of hexadecimal digit pairs to
  a binary.

  Rules (per PDF spec §7.4.2):
  - Whitespace (space, tab, CR, LF, FF, null) is ignored between pairs.
  - `>` (0x3E) is the end-of-data (EOD) marker; any bytes after it are ignored.
  - If the number of hex digits before EOD is odd, the last digit is padded
    with a trailing `0` nibble.
  - All other characters are an error.
  """

  @behaviour Pdf.Reader.Filter

  import Bitwise

  @doc """
  Decode ASCIIHex-encoded bytes.

  `params` is accepted but ignored (no DecodeParms defined for this filter).
  """
  @spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def decode(bytes, _params) do
    # Strip everything at and after the first ">" EOD marker
    stripped =
      case :binary.split(bytes, ">") do
        [before, _] -> before
        [all] -> all
      end

    # Remove whitespace
    hex =
      for <<c <- stripped>>,
          c not in [?\s, ?\t, ?\r, ?\n, ?\f, 0],
          into: <<>>,
          do: <<c>>

    decode_hex(hex, <<>>)
  end

  defp decode_hex(<<>>, acc), do: {:ok, acc}

  # Odd nibble at end — pad with 0
  defp decode_hex(<<h>>, acc) do
    with {:ok, high} <- hex_digit(h) do
      {:ok, acc <> <<bsl(high, 4)>>}
    end
  end

  defp decode_hex(<<h, l, rest::binary>>, acc) do
    with {:ok, high} <- hex_digit(h),
         {:ok, low} <- hex_digit(l) do
      decode_hex(rest, acc <> <<bor(bsl(high, 4), low)>>)
    end
  end

  defp hex_digit(c) when c in ?0..?9, do: {:ok, c - ?0}
  defp hex_digit(c) when c in ?A..?F, do: {:ok, c - ?A + 10}
  defp hex_digit(c) when c in ?a..?f, do: {:ok, c - ?a + 10}
  defp hex_digit(c), do: {:error, {:invalid_hex_char, <<c>>}}
end
