defmodule Pdf.Reader.Filter.RLE do
  @moduledoc """
  RunLengthDecode filter — decodes PackBits-style run-length encoded data.

  Per PDF spec §7.4.5:
  - Length byte 128 → end of data (EOD).
  - Length byte 0–127 → copy the next `n + 1` bytes verbatim (literal run).
  - Length byte 129–255 → repeat the next byte `257 - n` times (run).
  """

  @behaviour Pdf.Reader.Filter

  @doc """
  Decode RunLength-encoded bytes. `params` is ignored.
  """
  @spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def decode(bytes, _params), do: do_decode(bytes, <<>>)

  # EOD
  defp do_decode(<<128, _rest::binary>>, acc), do: {:ok, acc}
  defp do_decode(<<>>, acc), do: {:ok, acc}

  # Literal run: copy next n+1 bytes
  defp do_decode(<<n, rest::binary>>, acc) when n in 0..127 do
    count = n + 1

    case rest do
      <<literal::binary-size(count), tail::binary>> ->
        do_decode(tail, acc <> literal)

      _ ->
        {:error, {:rle_decode_error, :truncated_literal_run}}
    end
  end

  # Repeat run: repeat next byte (257 - n) times
  defp do_decode(<<n, byte, rest::binary>>, acc) when n in 129..255 do
    count = 257 - n
    repeated = :binary.copy(<<byte>>, count)
    do_decode(rest, acc <> repeated)
  end

  defp do_decode(_, _acc), do: {:error, {:rle_decode_error, :truncated}}
end
