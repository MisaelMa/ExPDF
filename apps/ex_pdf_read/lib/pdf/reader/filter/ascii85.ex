defmodule Pdf.Reader.Filter.ASCII85 do
  @moduledoc """
  ASCII85Decode filter — decodes ASCII base-85 encoded data to binary.

  Per PDF spec §7.4.3:
  - Characters `!` (0x21) through `u` (0x75) encode 5-char groups to 4 bytes.
  - `z` is a shortcut for a group of 5 `!` characters (representing 4 zero bytes).
  - `~>` is the end-of-data (EOD) marker; any subsequent bytes are ignored.
  - Whitespace (space, tab, CR, LF, FF) is ignored.
  - Partial final group (1–4 chars) maps to 1–3 output bytes using padding.
  """

  @behaviour Pdf.Reader.Filter

  # pow85 = [85^4, 85^3, 85^2, 85^1, 85^0]
  @pow85 [52_200_625, 614_125, 7225, 85, 1]

  @doc """
  Decode ASCII85-encoded bytes. `params` is ignored.
  """
  @spec decode(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def decode(bytes, _params) do
    # Strip everything at and after the "~>" EOD marker
    stripped =
      case :binary.split(bytes, "~>") do
        [before, _] -> before
        [all] -> all
      end

    # Remove whitespace
    chars =
      for <<c <- stripped>>,
          c not in [?\s, ?\t, ?\r, ?\n, ?\f],
          do: c

    decode_chars(chars, <<>>)
  end

  # Process 5-char groups
  defp decode_chars([], acc), do: {:ok, acc}

  # 'z' shortcut → four zero bytes
  defp decode_chars([?z | rest], acc) do
    decode_chars(rest, acc <> <<0, 0, 0, 0>>)
  end

  # Full 5-char group → 4 bytes
  defp decode_chars([c1, c2, c3, c4, c5 | rest], acc) do
    with {:ok, v} <- to_value([c1, c2, c3, c4, c5]) do
      decode_chars(rest, acc <> <<v::32>>)
    end
  end

  # Partial group at end (n = 2, 3, or 4 chars → n-1 bytes)
  defp decode_chars(chars, acc) when length(chars) in 2..4 do
    n = length(chars)
    # Pad to 5 chars with 'u' (0x75)
    padded = chars ++ List.duplicate(?u, 5 - n)

    with {:ok, v} <- to_value(padded) do
      # Output n-1 bytes (top bytes of the 32-bit value)
      out_bytes = n - 1
      bytes_out = :binary.part(<<v::32>>, 0, out_bytes)
      {:ok, acc <> bytes_out}
    end
  end

  defp decode_chars([_], _acc) do
    # A single char partial group is invalid per PDF spec
    {:error, {:ascii85_decode_error, :invalid_partial_group}}
  end

  # Convert 5 chars (each in '!'..'u' range) to a 32-bit integer
  defp to_value(chars) do
    chars
    |> Enum.zip(@pow85)
    |> Enum.reduce_while({:ok, 0}, fn {c, p}, {:ok, acc} ->
      if c in 0x21..0x75 do
        {:cont, {:ok, acc + (c - 0x21) * p}}
      else
        {:halt, {:error, {:ascii85_decode_error, {:invalid_char, <<c>>}}}}
      end
    end)
  end
end
