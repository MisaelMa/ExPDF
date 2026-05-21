defmodule ExQR.Encode do
  @moduledoc """
  QR Code data encoding: mode selection, bit stream construction,
  error correction block interleaving, and final codeword sequence.
  """

  import Bitwise
  alias ExQR.{Tables, ReedSolomon}

  @byte_mode 0b0100

  @doc """
  Encode text into the final codeword sequence (data + EC, interleaved).

  Returns `{:ok, version, codewords}` or `{:error, reason}`.
  """
  def encode(text, level \\ :m) when is_binary(text) do
    bytes = :binary.bin_to_list(text)
    byte_count = length(bytes)

    case Tables.min_version(byte_count, level) do
      {:error, _} = err ->
        err

      version ->
        {:ok, ec_info} = Tables.ec_info(version, level)
        cc_bits = Tables.char_count_bits(version)
        total_data_cw = ec_info.group1.blocks * ec_info.group1.data_codewords +
                        ec_info.group2.blocks * ec_info.group2.data_codewords

        bits =
          []
          |> append_bits(@byte_mode, 4)
          |> append_bits(byte_count, cc_bits)
          |> append_data_bytes(bytes)
          |> add_terminator(total_data_cw * 8)
          |> pad_to_byte()
          |> pad_codewords(total_data_cw)

        data_blocks = split_blocks(bits, ec_info)

        ec_blocks = Enum.map(data_blocks, fn block ->
          ReedSolomon.encode(block, ec_info.ec_per_block)
        end)

        interleaved = interleave(data_blocks) ++ interleave(ec_blocks)

        {:ok, version, interleaved}
    end
  end

  # ── Bit stream helpers ──────────────────────────────────────────

  defp append_bits(bits, value, count) do
    new_bits =
      (count - 1)..0//-1
      |> Enum.map(fn i -> (value >>> i) &&& 1 end)

    bits ++ new_bits
  end

  defp append_data_bytes(bits, bytes) do
    Enum.reduce(bytes, bits, fn byte, acc ->
      append_bits(acc, byte, 8)
    end)
  end

  defp add_terminator(bits, capacity_bits) do
    remaining = capacity_bits - length(bits)
    terminator_len = min(remaining, 4)
    bits ++ List.duplicate(0, terminator_len)
  end

  defp pad_to_byte(bits) do
    remainder = rem(length(bits), 8)
    if remainder == 0, do: bits, else: bits ++ List.duplicate(0, 8 - remainder)
  end

  defp pad_codewords(bits, total_cw) do
    codewords = bits_to_codewords(bits)
    remaining = total_cw - length(codewords)

    pad_bytes =
      Stream.cycle([0xEC, 0x11])
      |> Enum.take(max(remaining, 0))

    codewords ++ pad_bytes
  end

  defp bits_to_codewords(bits) do
    bits
    |> Enum.chunk_every(8)
    |> Enum.map(fn byte_bits ->
      byte_bits
      |> Enum.reduce(0, fn bit, acc -> (acc <<< 1) ||| bit end)
    end)
  end

  # ── Block splitting ─────────────────────────────────────────────

  defp split_blocks(codewords, ec_info) do
    %{group1: g1, group2: g2} = ec_info

    {g1_blocks, remaining} = take_blocks(codewords, g1.blocks, g1.data_codewords)

    {g2_blocks, _remaining} =
      if g2.blocks > 0 do
        take_blocks(remaining, g2.blocks, g2.data_codewords)
      else
        {[], remaining}
      end

    g1_blocks ++ g2_blocks
  end

  defp take_blocks(codewords, count, size) do
    Enum.reduce(1..max(count, 1), {[], codewords}, fn _, {blocks, rest} ->
      if count == 0 or rest == [] do
        {blocks, rest}
      else
        {block, remaining} = Enum.split(rest, size)
        {blocks ++ [block], remaining}
      end
    end)
  end

  # ── Interleaving ────────────────────────────────────────────────

  defp interleave([]), do: []

  defp interleave(blocks) do
    max_len = blocks |> Enum.map(&length/1) |> Enum.max()

    0..(max_len - 1)
    |> Enum.flat_map(fn i ->
      blocks
      |> Enum.filter(fn block -> i < length(block) end)
      |> Enum.map(fn block -> Enum.at(block, i) end)
    end)
  end
end
