defmodule Pdf.Reader.ObjectStream do
  @moduledoc """
  Decodes objects embedded in a PDF Object Stream (`/Type /ObjStm`).

  Per PDF 1.7 ISO 32000-1 § 7.5.7 "Object Streams":

  An Object Stream is a stream whose **decoded** body has two parts:

  1. **Header**: `N` whitespace-separated pairs `obj_num offset`, where
     `offset` is the byte offset of that object's value **relative to `/First`**.
  2. **Object values**: starting at byte `/First`, the `N` object bodies
     concatenated. Each body is a PDF value (integer, name, dictionary, array,
     etc.) but **never** a stream object — embedded streams are forbidden.

  ## Caller contract

  The caller (object resolver) is responsible for:
  1. Resolving the ObjStm indirect object itself.
  2. Decoding its filter chain (FlateDecode etc.) to get the raw body binary.
  3. Calling `fetch/3` with the decoded body, the `/First` offset, and
     the desired object's 0-based index within the stream.

  This design avoids a circular dependency between the resolver and ObjStm:
  the resolver is stateful (cache), ObjStm is pure (binary in, value out).

  ## Error reasons

  - `{:error, :objstm_index_out_of_range}` — index ≥ N (the object count).
  - `{:error, :malformed}` — header cannot be parsed.
  """

  alias Pdf.Reader.Parser

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Fetch the PDF value at 0-based `index` from a decoded ObjStm body.

  `first` is the `/First` value from the stream dictionary — the byte offset
  within `body` where object data starts.

  `body` is the **decoded** (filtered) stream body binary.

  Returns `{:ok, value}` or `{:error, reason}`.
  """
  @spec fetch(non_neg_integer(), binary(), non_neg_integer()) ::
          {:ok, term()} | {:error, term()}
  def fetch(first, body, index)
      when is_integer(first) and is_binary(body) and is_integer(index) do
    with {:ok, pairs} <- parse_header(body, first),
         :ok <- check_index(pairs, index) do
      fetch_value(body, first, pairs, index)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — header parsing
  # ---------------------------------------------------------------------------

  # Parse the N pairs "obj_num offset" from the header portion of the body.
  # Returns {:ok, [{obj_num, relative_offset}]} or {:error, :malformed}.
  defp parse_header(body, first) when byte_size(body) < first do
    {:error, :malformed}
  end

  defp parse_header(body, first) do
    header_binary = binary_part(body, 0, first)
    header_str = String.trim(header_binary)
    pairs = parse_pairs(header_str, [])
    {:ok, pairs}
  end

  # Parse "n1 o1 n2 o2 ..." pairs from a string.
  defp parse_pairs("", acc), do: Enum.reverse(acc)

  defp parse_pairs(str, acc) do
    case Integer.parse(String.trim_leading(str)) do
      {obj_num, rest} ->
        case Integer.parse(String.trim_leading(rest)) do
          {offset, rest2} ->
            parse_pairs(String.trim_leading(rest2), [{obj_num, offset} | acc])

          :error ->
            Enum.reverse(acc)
        end

      :error ->
        Enum.reverse(acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — index validation and value extraction
  # ---------------------------------------------------------------------------

  defp check_index(pairs, index) do
    if index < length(pairs) do
      :ok
    else
      {:error, :objstm_index_out_of_range}
    end
  end

  defp fetch_value(body, first, pairs, index) do
    {_obj_num, relative_offset} = Enum.at(pairs, index)

    # The object data starts at first + relative_offset.
    data_start = first + relative_offset
    data_size = byte_size(body) - data_start

    if data_start > byte_size(body) or data_size <= 0 do
      {:error, :malformed}
    else
      slice = binary_part(body, data_start, data_size)
      {value, _rest} = Parser.parse_value(slice)
      {:ok, value}
    end
  end
end
