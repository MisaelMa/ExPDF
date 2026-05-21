defmodule Pdf.Reader.XRef.Stream do
  @moduledoc """
  Parses a PDF 1.5+ compressed cross-reference stream (`/Type /XRef`).

  Per PDF 1.7 ISO 32000-1 § 7.5.8 "Cross-Reference Streams":

  - The stream object dictionary must have `/Type /XRef`.
  - Required fields: `/Size` (total object count), `/W [w1 w2 w3]` (byte widths).
  - Optional `/Index [first count ...]` — subsection ranges; default `[0 /Size]`.
  - Optional `/Prev` — byte offset of previous xref section (chain support).
  - The stream body (after decoding all filters) contains exactly
    `w1 + w2 + w3` bytes per entry:
      - Field 1 (w1 bytes): entry type. If w1 = 0, type is implicitly 1.
      - Field 2 (w2 bytes): meaning depends on type.
      - Field 3 (w3 bytes): meaning depends on type.

  Entry types (§ 7.5.8 Table 18):
  - **Type 0** (free): f2 = next free object number, f3 = generation when reused.
  - **Type 1** (in-use, classic): f2 = byte offset, f3 = generation number.
  - **Type 2** (compressed): f2 = object number of containing ObjStm, f3 = index within it.

  This module decodes the stream body using `Pdf.Reader.Filter.apply_chain/3`,
  which handles `FlateDecode` and PNG predictors transparently (batch 1 impl).
  """

  alias Pdf.Reader.Filter

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Parses a `/Type /XRef` stream object tuple into an xref entries map.

  Accepts `{:stream, dict, raw_bytes}` where `raw_bytes` is the still-encoded
  (FlateDecode-compressed) stream body.

  Returns:
  - `{:ok, entries_map}` — map of `{obj_num, gen_num} => entry`
  - `{:error, :not_an_xref_stream}` — dict does not have `/Type /XRef`
  - `{:error, reason}` — filter/decoding error propagated from the filter chain
  """
  @spec parse({:stream, map(), binary()}) ::
          {:ok, %{Pdf.Reader.Document.ref() => Pdf.Reader.Document.xref_entry()}}
          | {:error, term()}
  def parse({:stream, dict, raw_bytes}) do
    case dict["Type"] do
      {:name, "XRef"} ->
        do_parse(dict, raw_bytes)

      _ ->
        {:error, :not_an_xref_stream}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  defp do_parse(dict, raw_bytes) do
    # Decode the stream body through the filter chain (usually FlateDecode).
    with {:ok, decoded} <- decode_stream(dict, raw_bytes) do
      w = extract_w(dict)
      index_pairs = extract_index(dict)
      entries = parse_entries(decoded, w, index_pairs, %{})
      {:ok, entries}
    end
  end

  # Apply any filters listed in the stream dict to decode the body.
  # Filter names may be {:name, "FlateDecode"} tuples (from the parser) or plain
  # binary strings. Filter.apply_chain/3 handles both via resolve_module/1.
  defp decode_stream(dict, raw_bytes) do
    filter = Map.get(dict, "Filter")
    parms = Map.get(dict, "DecodeParms")

    if is_nil(filter) do
      # No filter — body is already in raw (uncompressed) form.
      {:ok, raw_bytes}
    else
      Filter.apply_chain(raw_bytes, filter, parms || %{})
    end
  end

  # Extract /W as a 3-tuple {w1, w2, w3}.
  # Per spec, each may be 0 to indicate a missing (defaulted) field.
  defp extract_w(%{"W" => [w1, w2, w3]}), do: {w1, w2, w3}
  defp extract_w(_), do: {1, 2, 1}

  # Extract /Index as a list of {first, count} pairs.
  # Default: [{0, Size}].
  defp extract_index(%{"Index" => index_list, "Size" => _size}) do
    pair_list(index_list)
  end

  defp extract_index(%{"Size" => size}) do
    [{0, size}]
  end

  defp extract_index(_), do: [{0, 0}]

  defp pair_list([]), do: []
  defp pair_list([first, count | rest]), do: [{first, count} | pair_list(rest)]

  # Walk all subsections in order.
  defp parse_entries(body, w, index_pairs, acc) do
    Enum.reduce(index_pairs, {body, acc}, fn {first, count}, {remaining, map} ->
      {rest, new_map} = read_subsection(remaining, w, first, count, map)
      {rest, new_map}
    end)
    |> elem(1)
  end

  # Read `count` entries for the subsection starting at object number `first`.
  defp read_subsection(body, w, first, count, acc) do
    Enum.reduce(0..(count - 1), {body, acc}, fn i, {remaining, map} ->
      {entry, rest} = read_entry(remaining, w, first + i)
      {rest, Map.put(map, elem(entry, 0), elem(entry, 1))}
    end)
  end

  # Read a single xref stream entry. Returns {{key, value}, rest_binary}.
  # PDF 1.7 § 7.5.8 Table 18 — entry field semantics.
  #
  # Note: Elixir binary pattern matching requires compile-time-known sizes.
  # We use `read_uint/2` to handle runtime-variable field widths.
  defp read_entry(body, {w1, w2, w3}, obj_num) do
    # Read field 1 (type): if w1 == 0, type is implicitly 1 (in_use).
    {type, after_type} =
      if w1 == 0 do
        {1, body}
      else
        {t, rest} = read_uint(body, w1)
        {t, rest}
      end

    # Read field 2 (f2).
    {f2, after_f2} = read_uint(after_type, w2)

    # Read field 3 (f3): if w3 == 0, default is 0.
    {f3, after_f3} =
      if w3 == 0 do
        {0, after_f2}
      else
        read_uint(after_f2, w3)
      end

    # Map type → entry shape, key → {obj_num, gen_num}.
    case type do
      0 ->
        # Type 0: free entry. gen = f3 (gen for next use).
        key = {obj_num, f3}
        {{key, :free}, after_f3}

      1 ->
        # Type 1: in_use. f2 = byte offset, f3 = generation.
        key = {obj_num, f3}
        {{key, {:in_use, f2, f3}}, after_f3}

      2 ->
        # Type 2: compressed. f2 = ObjStm obj_num, f3 = index within ObjStm.
        # Generation is always 0 for compressed objects (§ 7.5.8).
        key = {obj_num, 0}
        {{key, {:compressed, f2, f3}}, after_f3}

      _other ->
        # Unknown type — treat as free (spec says future types may be added).
        key = {obj_num, f3}
        {{key, :free}, after_f3}
    end
  end

  # Read `n` bytes from `binary` as a big-endian unsigned integer.
  # Returns {value, rest_binary}.
  # Uses binary_part/3 + :binary.decode_unsigned/2 to avoid compile-time
  # size constraints in pattern matching.
  defp read_uint(binary, n) when n > 0 and byte_size(binary) >= n do
    field = binary_part(binary, 0, n)
    rest = binary_part(binary, n, byte_size(binary) - n)
    value = :binary.decode_unsigned(field, :big)
    {value, rest}
  end
end
