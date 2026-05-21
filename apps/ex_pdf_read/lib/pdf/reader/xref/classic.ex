defmodule Pdf.Reader.XRef.Classic do
  @moduledoc """
  Parses a classic PDF cross-reference table (keyword `xref`).

  Per PDF spec § 7.5.4:
  - Starts with the `xref` keyword on its own line.
  - Followed by one or more subsections. Each subsection has a header line
    `<first_obj_num> <count>` and then exactly `count` 20-byte entries.
  - Each entry format: `<10-digit-offset> <5-digit-gen> <n|f><EOL>`
    where EOL is `\\r\\n`, ` \\r`, or ` \\n` (3 variants = 20 bytes total).
  - After all subsections, a `trailer` keyword + dictionary.
  """

  alias Pdf.Reader.Parser

  @type xref_entry ::
          {:in_use, non_neg_integer(), non_neg_integer()}
          | :free

  @type entries :: %{{pos_integer(), non_neg_integer()} => xref_entry()}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Parses a classic xref table starting at `offset` within `binary`.

  Returns `{:ok, entries_map}` where keys are `{obj_num, gen_num}` and values
  are `{:in_use, offset, gen}` or `:free`.

  Returns `{:error, reason}` if the binary at that offset is not a valid
  classic xref section.
  """
  @spec parse(binary(), non_neg_integer()) :: {:ok, entries()} | {:error, term()}
  def parse(binary, offset) when is_binary(binary) and is_integer(offset) do
    total = byte_size(binary)

    if offset >= total do
      {:error, :offset_out_of_range}
    else
      slice = binary_part(binary, offset, total - offset)
      do_parse(slice)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal parsing
  # ---------------------------------------------------------------------------

  defp do_parse(<<"xref", rest::binary>>) do
    rest2 = skip_eol(rest)
    parse_subsections(rest2, %{})
  end

  defp do_parse(_), do: {:error, :not_an_xref}

  # Parse subsection headers until we hit "trailer"
  defp parse_subsections(rest, entries) do
    rest = skip_whitespace(rest)

    if String.starts_with?(rest, "trailer") do
      {:ok, entries}
    else
      case parse_subsection_header(rest) do
        {:ok, first, count, rest2} ->
          {new_entries, rest3} = parse_entries(rest2, first, count, %{})
          parse_subsections(rest3, Map.merge(entries, new_entries))

        :error ->
          {:error, :invalid_xref_subsection}
      end
    end
  end

  # Parse "first count\n" subsection header
  defp parse_subsection_header(bin) do
    case Integer.parse(bin) do
      {first, rest} ->
        rest = skip_spaces(rest)

        case Integer.parse(rest) do
          {count, rest2} ->
            rest3 = skip_eol(rest2)
            {:ok, first, count, rest3}

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  # Parse `count` 20-byte entries starting at obj number `first`
  defp parse_entries(rest, _first, 0, acc), do: {acc, rest}

  defp parse_entries(
         <<offset_str::binary-size(10), _sp1, gen_str::binary-size(5), _sp2, kind,
           _eol::binary-size(2), rest::binary>>,
         first,
         count,
         acc
       ) do
    offset = String.to_integer(offset_str)
    gen = String.to_integer(gen_str)

    entry =
      case kind do
        ?f -> :free
        ?n -> {:in_use, offset, gen}
        _ -> {:in_use, offset, gen}
      end

    # Key: {obj_num, gen_num}
    key = {first, gen}
    parse_entries(rest, first + 1, count - 1, Map.put(acc, key, entry))
  end

  defp parse_entries(rest, _first, _count, acc), do: {acc, rest}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp skip_eol(<<?\r, ?\n, rest::binary>>), do: rest
  defp skip_eol(<<?\r, rest::binary>>), do: rest
  defp skip_eol(<<?\n, rest::binary>>), do: rest
  defp skip_eol(rest), do: rest

  defp skip_whitespace(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r, ?\n, ?\f, 0] do
    skip_whitespace(rest)
  end

  defp skip_whitespace(rest), do: rest

  defp skip_spaces(<<?\s, rest::binary>>), do: skip_spaces(rest)
  defp skip_spaces(<<?\t, rest::binary>>), do: skip_spaces(rest)
  defp skip_spaces(rest), do: rest

  # Public but unused here — keep for downstream use
  @doc false
  def parse_trailer_dict(binary, offset) do
    total = byte_size(binary)

    if offset >= total do
      {:error, :malformed}
    else
      slice = binary_part(binary, offset, total - offset)

      case :binary.match(slice, "trailer") do
        {pos, len} ->
          after_kw = binary_part(slice, pos + len, byte_size(slice) - pos - len)
          {dict, _rest} = Parser.parse_value(String.trim_leading(after_kw))
          {:ok, dict}

        :nomatch ->
          {:error, :no_trailer}
      end
    end
  end
end
