defmodule Pdf.Reader.CMap do
  @moduledoc """
  Parser for the ToUnicode CMap subset used in PDF fonts.

  Spec reference: PDF 1.7 § 9.10.3 and Adobe Tech Note 5099
  (CMap and CIDFont Files Specification).

  ## Supported subset

  Only `beginbfchar`/`endbfchar` and `beginbfrange`/`endbfrange` sections
  are parsed. Everything else (codespacerange, cidchar, cidrange, notdefchar,
  notdefrange, and PostScript prologue/epilogue) is silently skipped.

  ## Data shape

      %Pdf.Reader.CMap{
        bf_char: %{integer => String.t()},       # O(log n) map lookup
        bf_range: [{lo, hi, dst}]                # linear scan, dst is String.t() or [String.t()]
      }

  ## Lookup order

  1. `bf_char` (O(log n) map) — checked first.
  2. `bf_range` (linear, typically < 10 entries) — checked on miss.

  Returns `nil` if not mapped by either table.

  ## UTF-16BE decoding

  Hex strings in the CMap (`<HHHH...>`) are UTF-16BE encoded codepoint sequences.
  Erlang's `:unicode.characters_to_binary/3` converts them to UTF-8 (Elixir `String.t()`).
  """

  @type t :: %__MODULE__{
          bf_char: %{non_neg_integer() => String.t()},
          bf_range: [{non_neg_integer(), non_neg_integer(), String.t() | [String.t()]}]
        }

  defstruct bf_char: %{}, bf_range: []

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Parses a ToUnicode CMap binary into a `%Pdf.Reader.CMap{}` struct.

  Only `bfchar` and `bfrange` sections are extracted.
  All other PostScript CMap constructs are skipped silently.
  """
  @spec parse(binary()) :: t()
  def parse(binary) when is_binary(binary) do
    do_parse(binary, %__MODULE__{})
  end

  @doc """
  Looks up a character code in the CMap.

  Returns the corresponding UTF-8 `String.t()` or `nil` if not mapped.
  Lookup order: `bf_char` first (O(log n)), then `bf_range` (linear scan).
  """
  @spec lookup(t(), non_neg_integer()) :: String.t() | nil
  def lookup(%__MODULE__{bf_char: bf_char, bf_range: bf_range}, code) do
    case Map.fetch(bf_char, code) do
      {:ok, str} -> str
      :error -> lookup_range(bf_range, code)
    end
  end

  # ---------------------------------------------------------------------------
  # Parser internals
  # ---------------------------------------------------------------------------

  # Main parse loop — scan for section keywords, dispatch, accumulate.
  defp do_parse(binary, cmap) do
    case scan_for_section(binary) do
      {:bfchar, count, rest} ->
        {entries, after_section} = parse_bfchar_section(rest, count)
        merged = Map.merge(cmap.bf_char, entries)
        do_parse(after_section, %{cmap | bf_char: merged})

      {:bfrange, count, rest} ->
        {entries, after_section} = parse_bfrange_section(rest, count)
        do_parse(after_section, %{cmap | bf_range: cmap.bf_range ++ entries})

      {:skip_section, _keyword, rest} ->
        # Unknown section — skip until the matching end* keyword
        do_parse(rest, cmap)

      :done ->
        cmap
    end
  end

  # Scan forward for the next section begin keyword.
  # Returns {:bfchar, count, rest} | {:bfrange, count, rest} | {:skip_section, kw, rest} | :done
  defp scan_for_section(binary) do
    case Regex.run(
           ~r/(\d+)\s+begin(bfchar|bfrange|codespacerange|cidchar|cidrange|notdefchar|notdefrange)/,
           binary,
           return: :index
         ) do
      nil ->
        :done

      [{full_start, full_len}, {_count_start, count_len}, {kw_rel, kw_len}] ->
        count_start = full_start
        count_str = binary_part(binary, count_start, count_len)
        count = String.to_integer(count_str)
        full_end = full_start + full_len
        keyword = binary_part(binary, kw_rel, kw_len)
        rest = binary_part(binary, full_end, byte_size(binary) - full_end)

        case keyword do
          "bfchar" -> {:bfchar, count, rest}
          "bfrange" -> {:bfrange, count, rest}
          _ -> {:skip_section, keyword, skip_to_end(rest, keyword)}
        end
    end
  end

  # Skip bytes until we find "end<keyword>"
  defp skip_to_end(binary, keyword) do
    end_kw = "end" <> keyword

    case :binary.match(binary, end_kw) do
      {pos, len} ->
        skip_pos = pos + len
        binary_part(binary, skip_pos, byte_size(binary) - skip_pos)

      :nomatch ->
        # Malformed — no end keyword found; return empty
        ""
    end
  end

  # ---------------------------------------------------------------------------
  # bfchar section parser
  # ---------------------------------------------------------------------------

  defp parse_bfchar_section(binary, count) do
    {pairs, rest} = collect_bfchar_pairs(binary, count, [])
    entries = Map.new(pairs)
    {entries, rest}
  end

  defp collect_bfchar_pairs(binary, 0, acc), do: {Enum.reverse(acc), skip_end_bfchar(binary)}

  defp collect_bfchar_pairs(binary, n, acc) do
    case parse_hex_pair(binary) do
      {:ok, src_bytes, dst_bytes, rest} ->
        src_code = :binary.decode_unsigned(src_bytes, :big)
        dst_str = decode_utf16be(dst_bytes)
        collect_bfchar_pairs(rest, n - 1, [{src_code, dst_str} | acc])

      :error ->
        {Enum.reverse(acc), binary}
    end
  end

  defp skip_end_bfchar(binary) do
    case :binary.match(binary, "endbfchar") do
      {pos, len} ->
        skip = pos + len
        binary_part(binary, skip, byte_size(binary) - skip)

      :nomatch ->
        ""
    end
  end

  # ---------------------------------------------------------------------------
  # bfrange section parser
  # ---------------------------------------------------------------------------

  defp parse_bfrange_section(binary, count) do
    {entries, rest} = collect_bfrange_entries(binary, count, [])
    {Enum.reverse(entries), rest}
  end

  defp collect_bfrange_entries(binary, 0, acc), do: {acc, skip_end_bfrange(binary)}

  defp collect_bfrange_entries(binary, n, acc) do
    case parse_bfrange_entry(binary) do
      {:ok, lo, hi, dst, rest} ->
        collect_bfrange_entries(rest, n - 1, [{lo, hi, dst} | acc])

      :error ->
        {acc, binary}
    end
  end

  defp skip_end_bfrange(binary) do
    case :binary.match(binary, "endbfrange") do
      {pos, len} ->
        skip = pos + len
        binary_part(binary, skip, byte_size(binary) - skip)

      :nomatch ->
        ""
    end
  end

  # Parses one bfrange entry: either string-base form or array form.
  # String-base: <lo> <hi> <dst_start>
  # Array form:  <lo> <hi> [<dst1> <dst2> ...]
  defp parse_bfrange_entry(binary) do
    trimmed = String.trim_leading(binary)

    case parse_hex_token(trimmed) do
      {:ok, lo_bytes, after_lo} ->
        case parse_hex_token(String.trim_leading(after_lo)) do
          {:ok, hi_bytes, after_hi} ->
            lo = :binary.decode_unsigned(lo_bytes, :big)
            hi = :binary.decode_unsigned(hi_bytes, :big)
            after_hi2 = String.trim_leading(after_hi)

            cond do
              # Array form: starts with [
              String.starts_with?(after_hi2, "[") ->
                case parse_hex_array(after_hi2) do
                  {:ok, strs, rest} -> {:ok, lo, hi, strs, rest}
                  :error -> :error
                end

              # String-base form: next token is a hex string
              String.starts_with?(after_hi2, "<") ->
                case parse_hex_token(after_hi2) do
                  {:ok, dst_bytes, rest} ->
                    dst_str = decode_utf16be(dst_bytes)
                    {:ok, lo, hi, dst_str, rest}

                  :error ->
                    :error
                end

              true ->
                :error
            end

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  # Parses an array of hex strings: [<hex1> <hex2> ...]
  defp parse_hex_array("[" <> rest) do
    parse_hex_array_items(String.trim_leading(rest), [])
  end

  defp parse_hex_array(_), do: :error

  defp parse_hex_array_items("]" <> rest, acc) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp parse_hex_array_items(binary, acc) do
    binary = String.trim_leading(binary)

    cond do
      String.starts_with?(binary, "]") ->
        {:ok, Enum.reverse(acc), String.slice(binary, 1..-1//1)}

      String.starts_with?(binary, "<") ->
        case parse_hex_token(binary) do
          {:ok, bytes, rest} ->
            str = decode_utf16be(bytes)
            parse_hex_array_items(String.trim_leading(rest), [str | acc])

          :error ->
            :error
        end

      binary == "" ->
        :error

      true ->
        :error
    end
  end

  # ---------------------------------------------------------------------------
  # Hex token / pair parsers
  # ---------------------------------------------------------------------------

  # Parse two adjacent hex tokens: <HEX> <HEX>
  defp parse_hex_pair(binary) do
    trimmed = String.trim_leading(binary)

    case parse_hex_token(trimmed) do
      {:ok, src_bytes, rest} ->
        case parse_hex_token(String.trim_leading(rest)) do
          {:ok, dst_bytes, rest2} -> {:ok, src_bytes, dst_bytes, rest2}
          :error -> :error
        end

      :error ->
        :error
    end
  end

  # Parse a single <HEXDIGITS> token. Returns {:ok, binary_bytes, rest_binary}.
  defp parse_hex_token("<" <> rest) do
    case :binary.match(rest, ">") do
      {pos, _} ->
        hex_str = binary_part(rest, 0, pos)
        after_gt = binary_part(rest, pos + 1, byte_size(rest) - pos - 1)
        {:ok, hex_to_binary(hex_str), after_gt}

      :nomatch ->
        :error
    end
  end

  defp parse_hex_token(_), do: :error

  # Convert a hex string (e.g. "0041") to its binary bytes (e.g. <<0, 65>>).
  defp hex_to_binary(hex_str) do
    hex_str
    |> String.replace(~r/\s/, "")
    |> Base.decode16!(case: :mixed)
  end

  # ---------------------------------------------------------------------------
  # UTF-16BE → UTF-8 decoder
  # ---------------------------------------------------------------------------

  # Decodes a binary of UTF-16BE bytes into a UTF-8 Elixir string.
  # Uses Erlang stdlib :unicode — confirmed available (OTP stdlib).
  # Spec ref: PDF 1.7 § 9.10.3 — dst hex strings are UTF-16BE encoded.
  defp decode_utf16be(bytes) when is_binary(bytes) do
    case :unicode.characters_to_binary(bytes, {:utf16, :big}, :utf8) do
      result when is_binary(result) -> result
      # On failure fall back to replacement char
      _ -> "�"
    end
  end

  # ---------------------------------------------------------------------------
  # Range lookup
  # ---------------------------------------------------------------------------

  defp lookup_range([], _code), do: nil

  defp lookup_range([{lo, hi, dst} | rest], code) do
    if code >= lo and code <= hi do
      case dst do
        # Array form: direct element at offset
        strings when is_list(strings) ->
          Enum.at(strings, code - lo)

        # String-base form: increment the last UTF-16BE codepoint by offset
        base_str when is_binary(base_str) ->
          offset = code - lo
          increment_last_codepoint(base_str, offset)
      end
    else
      lookup_range(rest, code)
    end
  end

  # Increment the LAST Unicode codepoint in a string by `offset`.
  # This implements the bfrange string-base rule: for code = lo + n,
  # the dst is base_str with the last codepoint incremented by n.
  # Spec: PDF 1.7 § 9.10.3, Adobe TN 5099.
  defp increment_last_codepoint(str, 0), do: str

  defp increment_last_codepoint(str, offset) do
    codepoints = String.codepoints(str)

    case Enum.split(codepoints, length(codepoints) - 1) do
      {prefix, [last]} ->
        last_cp = String.to_charlist(last) |> hd()
        new_cp = last_cp + offset
        IO.iodata_to_binary([prefix, [<<new_cp::utf8>>]])

      _ ->
        str
    end
  end
end
