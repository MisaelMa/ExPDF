defmodule ExBarcode.Code128 do
  @moduledoc """
  Code 128 barcode encoder.

  Encodes a string into a list of bar widths suitable for rendering.
  Supports Code 128B (full ASCII) with automatic Code C optimization
  for runs of digit pairs.

  ## Reference

  Code 128 uses three character sets (A, B, C). This implementation
  primarily uses Code B (covers ASCII 32–127) with automatic switching
  to Code C for efficient encoding of digit pairs.
  """

  # Code 128 bar patterns — each symbol is 6 alternating bars/spaces
  # Values represent widths: [bar, space, bar, space, bar, space]
  @patterns [
    {0, [2, 1, 2, 2, 2, 2]},
    {1, [2, 2, 2, 1, 2, 2]},
    {2, [2, 2, 2, 2, 2, 1]},
    {3, [1, 2, 1, 2, 2, 3]},
    {4, [1, 2, 1, 3, 2, 2]},
    {5, [1, 3, 1, 2, 2, 2]},
    {6, [1, 2, 2, 2, 1, 3]},
    {7, [1, 2, 2, 3, 1, 2]},
    {8, [1, 3, 2, 2, 1, 2]},
    {9, [2, 2, 1, 2, 1, 3]},
    {10, [2, 2, 1, 3, 1, 2]},
    {11, [2, 3, 1, 2, 1, 2]},
    {12, [1, 1, 2, 2, 3, 2]},
    {13, [1, 2, 2, 1, 3, 2]},
    {14, [1, 2, 2, 2, 3, 1]},
    {15, [1, 1, 3, 2, 2, 2]},
    {16, [1, 2, 3, 1, 2, 2]},
    {17, [1, 2, 3, 2, 2, 1]},
    {18, [2, 2, 3, 2, 1, 1]},
    {19, [2, 2, 1, 1, 3, 2]},
    {20, [2, 2, 1, 2, 3, 1]},
    {21, [2, 1, 3, 2, 1, 2]},
    {22, [2, 2, 3, 1, 1, 2]},
    {23, [3, 1, 2, 1, 3, 1]},
    {24, [3, 1, 1, 2, 2, 2]},
    {25, [3, 2, 1, 1, 2, 2]},
    {26, [3, 2, 1, 2, 2, 1]},
    {27, [3, 1, 2, 2, 1, 2]},
    {28, [3, 2, 2, 1, 1, 2]},
    {29, [3, 2, 2, 2, 1, 1]},
    {30, [2, 1, 2, 1, 2, 3]},
    {31, [2, 1, 2, 3, 2, 1]},
    {32, [2, 3, 2, 1, 2, 1]},
    {33, [1, 1, 1, 3, 2, 3]},
    {34, [1, 3, 1, 1, 2, 3]},
    {35, [1, 3, 1, 3, 2, 1]},
    {36, [1, 1, 2, 3, 2, 2]},
    {37, [1, 3, 2, 1, 2, 2]},
    {38, [1, 3, 2, 3, 2, 0]},
    {39, [2, 1, 1, 3, 1, 3]},
    {40, [2, 3, 1, 1, 1, 3]},
    {41, [2, 3, 1, 3, 1, 1]},
    {42, [1, 1, 2, 1, 3, 3]},
    {43, [1, 1, 2, 3, 3, 1]},
    {44, [1, 3, 2, 1, 3, 1]},
    {45, [1, 1, 3, 1, 2, 3]},
    {46, [1, 1, 3, 3, 2, 1]},
    {47, [1, 3, 3, 1, 2, 1]},
    {48, [3, 1, 3, 1, 2, 1]},
    {49, [2, 1, 1, 3, 3, 1]},
    {50, [2, 3, 1, 1, 3, 1]},
    {51, [2, 1, 3, 1, 1, 3]},
    {52, [2, 1, 3, 3, 1, 1]},
    {53, [2, 1, 3, 1, 3, 1]},
    {54, [3, 1, 1, 1, 2, 3]},
    {55, [3, 1, 1, 3, 2, 1]},
    {56, [3, 3, 1, 1, 2, 1]},
    {57, [3, 1, 2, 1, 1, 3]},
    {58, [3, 1, 2, 3, 1, 1]},
    {59, [3, 3, 2, 1, 1, 1]},
    {60, [2, 1, 2, 1, 3, 2]},
    {61, [2, 1, 2, 2, 3, 1]},
    {62, [2, 1, 2, 1, 1, 4]},
    {63, [4, 3, 1, 1, 1, 1]},
    {64, [2, 1, 1, 1, 4, 2]},
    {65, [1, 2, 1, 1, 4, 2]},
    {66, [1, 2, 1, 2, 4, 1]},
    {67, [4, 1, 1, 2, 1, 2]},
    {68, [4, 2, 1, 1, 1, 2]},
    {69, [4, 2, 1, 2, 1, 1]},
    {70, [2, 1, 4, 1, 2, 1]},
    {71, [2, 1, 1, 4, 1, 2]},
    {72, [4, 1, 2, 1, 1, 2]},
    {73, [2, 4, 1, 2, 1, 1]},
    {74, [1, 1, 4, 1, 2, 2]},
    {75, [1, 2, 4, 1, 2, 1]},
    {76, [1, 2, 4, 2, 1, 1]},
    {77, [4, 1, 1, 1, 2, 2]},
    {78, [4, 1, 2, 2, 1, 1]},
    {79, [2, 2, 1, 4, 1, 1]},
    {80, [2, 4, 1, 1, 1, 2]},
    {81, [1, 1, 1, 2, 4, 2]},
    {82, [1, 2, 1, 1, 2, 4]},
    {83, [1, 2, 1, 4, 2, 1]},
    {84, [1, 1, 4, 2, 2, 1]},
    {85, [1, 2, 4, 1, 1, 2]},
    {86, [1, 4, 2, 1, 2, 1]},
    {87, [1, 4, 1, 2, 1, 2]},
    {88, [4, 1, 2, 1, 2, 1]},
    {89, [2, 1, 1, 1, 2, 4]},
    {90, [2, 1, 4, 2, 1, 1]},
    {91, [2, 4, 2, 1, 1, 1]},
    {92, [1, 1, 1, 1, 4, 3]},
    {93, [1, 1, 1, 3, 4, 1]},
    {94, [1, 3, 1, 1, 4, 1]},
    {95, [1, 1, 4, 1, 1, 3]},
    {96, [1, 1, 4, 3, 1, 1]},
    {97, [4, 1, 1, 1, 1, 3]},
    {98, [4, 1, 1, 3, 1, 1]},
    {99, [1, 1, 3, 1, 4, 1]},
    {100, [1, 1, 4, 1, 3, 1]},
    {101, [3, 1, 1, 1, 4, 1]},
    {102, [4, 1, 1, 1, 3, 1]},
    {103, [2, 1, 1, 4, 1, 2]},
    {104, [2, 1, 1, 2, 1, 4]},
    {105, [2, 1, 1, 2, 3, 2]}
  ]

  @stop_pattern [2, 3, 3, 1, 1, 1, 2]

  @pattern_map Map.new(@patterns)

  @code_b_start 104
  @code_c_switch 99
  @code_b_switch 100

  @doc """
  Encode a string into Code 128 bar pattern.

  Returns `{:ok, bars}` where `bars` is a flat list of integers
  representing alternating bar and space widths (starting with a bar).

  Returns `{:error, reason}` if the input contains unsupported characters.
  """
  @spec encode(String.t()) :: {:ok, list(integer())} | {:error, atom()}
  def encode(text) when is_binary(text) do
    chars = String.to_charlist(text)

    if Enum.all?(chars, &(&1 >= 32 and &1 <= 126)) do
      values = encode_values(chars)
      checksum = compute_checksum(values)
      all_values = values ++ [checksum]

      bars =
        all_values
        |> Enum.flat_map(fn v -> Map.fetch!(@pattern_map, v) end)
        |> Kernel.++(@stop_pattern)

      {:ok, bars}
    else
      {:error, :unsupported_characters}
    end
  end

  def encode(_), do: {:error, :invalid_input}

  @doc """
  Same as `encode/1` but raises on error.
  """
  def encode!(text) do
    case encode(text) do
      {:ok, bars} -> bars
      {:error, reason} -> raise ArgumentError, "Code128 encode error: #{reason}"
    end
  end

  @doc """
  Calculate the total width in modules (unit bar widths) for a given text.
  """
  def total_modules(text) when is_binary(text) do
    case encode(text) do
      {:ok, bars} -> Enum.sum(bars)
      {:error, _} = err -> err
    end
  end

  # ── Encoding logic ──────────────────────────────────────────────

  defp encode_values(chars) do
    {values, _mode} = encode_chars(chars, :b, [])
    [@code_b_start | Enum.reverse(values)]
  end

  defp encode_chars([], _mode, acc), do: {acc, :b}

  defp encode_chars(chars, :b, acc) do
    case count_leading_digits(chars) do
      n when n >= 4 ->
        {digit_pairs, rest} = take_digit_pairs(chars, n)
        c_values = Enum.map(digit_pairs, fn {d1, d2} -> (d1 - ?0) * 10 + (d2 - ?0) end)
        encode_chars(rest, :c, Enum.reverse(c_values) ++ [@code_c_switch | acc])

      _ ->
        [ch | rest] = chars
        encode_chars(rest, :b, [ch - 32 | acc])
    end
  end

  defp encode_chars(chars, :c, acc) do
    case count_leading_digits(chars) do
      n when n >= 2 ->
        {digit_pairs, rest} = take_digit_pairs(chars, n)
        c_values = Enum.map(digit_pairs, fn {d1, d2} -> (d1 - ?0) * 10 + (d2 - ?0) end)
        encode_chars(rest, :c, Enum.reverse(c_values) ++ acc)

      _ ->
        encode_chars(chars, :b, [@code_b_switch | acc])
    end
  end

  defp count_leading_digits(chars) do
    chars
    |> Enum.take_while(fn ch -> ch >= ?0 and ch <= ?9 end)
    |> length()
  end

  defp take_digit_pairs(chars, count) do
    pair_count = div(count, 2)
    {digits, rest} = Enum.split(chars, pair_count * 2)

    pairs =
      digits
      |> Enum.chunk_every(2)
      |> Enum.map(fn [a, b] -> {a, b} end)

    {pairs, rest}
  end

  defp compute_checksum([start | data_values]) do
    weighted_sum =
      data_values
      |> Enum.with_index(1)
      |> Enum.reduce(start, fn {val, weight}, sum -> sum + val * weight end)

    rem(weighted_sum, 103)
  end
end
