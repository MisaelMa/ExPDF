defmodule Pdf.Reader.Parser do
  @moduledoc """
  PDF recursive-descent parser.

  Converts a PDF binary into the tagged-tuple internal value representation
  defined in the design:

    - integers → `integer()`
    - reals → `float()`
    - booleans → `true | false`
    - null → `:null`
    - names → `{:name, binary()}`
    - literal strings → `{:string, binary()}`
    - hex strings → `{:hex_string, binary()}`
    - arrays → Elixir `list()`
    - dictionaries → `%{binary() => value()}` (keys without leading `/`)
    - indirect refs → `{:ref, n, g}`
    - streams → `{:stream, dict_map, raw_bytes}`

  References are NEVER resolved here — they come out as `{:ref, n, g}` tuples
  for lazy resolution by `Pdf.Reader.ObjectResolver`.
  """

  alias Pdf.Reader.Lexer

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Parses a single PDF value from `binary`. Returns `{value, rest}`.

  The `rest` binary is the unconsumed input after the value ends.
  """
  @spec parse_value(binary()) :: {term(), binary()}
  def parse_value(binary) when is_binary(binary) do
    binary |> Lexer.next_token() |> lift_token(binary)
  end

  @doc """
  Parses a full indirect object `N G obj <value> endobj` from `binary`.

  Returns `{:ok, {n, g}, value, rest}` on success, or `{:error, reason}` on failure.

  For stream objects the value is `{:stream, dict_map, raw_bytes}` where
  `raw_bytes` is the UNFILTERED payload.
  """
  @spec parse_object(binary()) ::
          {:ok, {pos_integer(), non_neg_integer()}, term(), binary()}
          | {:error, term()}
  def parse_object(binary) when is_binary(binary) do
    with {{:integer, n}, rest1} <- Lexer.next_token(binary),
         {{:integer, g}, rest2} <- Lexer.next_token(rest1),
         {:obj, rest3} <- Lexer.next_token(rest2) do
      {value, rest4} = parse_value(rest3)
      finish_object(n, g, value, rest4)
    else
      _ -> {:error, :not_an_object}
    end
  end

  # ---------------------------------------------------------------------------
  # Finish object after value is parsed — handle stream or endobj
  # ---------------------------------------------------------------------------

  defp finish_object(n, g, dict, rest) when is_map(dict) do
    # Might be a stream — peek for "stream" keyword
    case Lexer.next_token(rest) do
      {:stream, rest2} ->
        raw = read_stream_bytes(dict, rest2)
        # Consume the leading \n or \r\n BEFORE content
        {payload, rest3} = read_stream_payload(dict, raw)
        # Find endstream + endobj after payload
        rest4 = skip_past_endobj(rest3)
        {:ok, {n, g}, {:stream, dict, payload}, rest4}

      {:endobj, rest2} ->
        {:ok, {n, g}, dict, rest2}

      _ ->
        {:error, {:unexpected_token, :expected_endobj}}
    end
  end

  defp finish_object(n, g, value, rest) do
    case Lexer.next_token(rest) do
      {:endobj, rest2} -> {:ok, {n, g}, value, rest2}
      _ -> {:error, {:unexpected_token, :expected_endobj}}
    end
  end

  # After the `stream` keyword, PDF spec says:
  # the NEXT byte after keyword must be CR LF or just LF.
  # raw_bytes here = everything after `stream` (no preceding newline consumed yet)
  defp read_stream_payload(dict, rest) do
    # Skip the mandatory end-of-line after the `stream` keyword
    rest2 =
      case rest do
        <<13, 10, r::binary>> -> r
        <<10, r::binary>> -> r
        <<13, r::binary>> -> r
        r -> r
      end

    len = get_length(dict)

    if is_integer(len) and len >= 0 do
      <<payload::binary-size(len), rest3::binary>> = rest2
      {payload, rest3}
    else
      # /Length is an indirect ref or missing — read until endstream
      read_until_endstream(rest2, <<>>)
    end
  end

  defp read_stream_bytes(_dict, rest), do: rest

  defp get_length(dict) do
    case Map.get(dict, "Length") do
      v when is_integer(v) -> v
      _ -> :unknown
    end
  end

  defp read_until_endstream(<<"endstream", rest::binary>>, acc), do: {acc, rest}

  defp read_until_endstream(<<c, rest::binary>>, acc) do
    read_until_endstream(rest, <<acc::binary, c>>)
  end

  defp read_until_endstream(<<>>, acc), do: {acc, <<>>}

  defp skip_past_endobj(rest) do
    case Lexer.next_token(rest) do
      {:endstream, rest2} -> skip_endobj(rest2)
      {:endobj, rest2} -> rest2
      {_, rest2} -> skip_past_endobj(rest2)
      :eof -> <<>>
    end
  end

  defp skip_endobj(rest) do
    case Lexer.next_token(rest) do
      {:endobj, rest2} -> rest2
      _ -> rest
    end
  end

  # ---------------------------------------------------------------------------
  # Token lifting — convert Lexer token into parser value
  # ---------------------------------------------------------------------------

  defp lift_token(:eof, _original), do: {:eof, <<>>}

  defp lift_token({{:integer, n}, rest}, _) do
    # Could be a real, bool, name, etc. — but first check for indirect ref
    # An indirect ref is: integer integer R
    # We need to look ahead
    maybe_ref(n, rest)
  end

  defp lift_token({{:real, f}, rest}, _), do: {f, rest}
  defp lift_token({{:boolean, b}, rest}, _), do: {b, rest}
  defp lift_token({:null, rest}, _), do: {:null, rest}
  defp lift_token({{:name, n}, rest}, _), do: {{:name, n}, rest}
  defp lift_token({{:string, s}, rest}, _), do: {{:string, s}, rest}
  defp lift_token({{:hex_string, s}, rest}, _), do: {{:hex_string, s}, rest}
  defp lift_token({:array_open, rest}, _), do: parse_array(rest, [])
  defp lift_token({:dict_open, rest}, _), do: parse_dict(rest, %{})

  defp lift_token({unexpected, _rest}, _original) do
    raise ArgumentError, "Unexpected token in value position: #{inspect(unexpected)}"
  end

  # ---------------------------------------------------------------------------
  # Indirect reference look-ahead
  # When we see an integer, peek for "integer R" to form a ref
  # ---------------------------------------------------------------------------

  defp maybe_ref(n, rest) do
    case Lexer.next_token(rest) do
      {{:integer, g}, rest2} ->
        case Lexer.next_token(rest2) do
          {:r, rest3} -> {{:ref, n, g}, rest3}
          # Not a ref — second integer is a separate value; return first
          # But we consumed both, which is a problem if we're parsing e.g. [1 2 3]
          # We can't "unread" — but this situation only arises at value boundaries.
          # Return n and leave rest as-is (before the second integer)
          _ -> {n, rest}
        end

      _ ->
        # Not followed by integer — just return the integer
        {n, rest}
    end
  end

  # ---------------------------------------------------------------------------
  # Array parsing — after [ consumed
  # ---------------------------------------------------------------------------

  defp parse_array(rest, acc) do
    case Lexer.next_token(rest) do
      {:array_close, rest2} ->
        {Enum.reverse(acc), rest2}

      :eof ->
        {Enum.reverse(acc), <<>>}

      token ->
        {value, rest2} = lift_token(token, rest)
        parse_array(rest2, [value | acc])
    end
  end

  # ---------------------------------------------------------------------------
  # Dictionary parsing — after << consumed
  # ---------------------------------------------------------------------------

  defp parse_dict(rest, acc) do
    case Lexer.next_token(rest) do
      {:dict_close, rest2} ->
        {acc, rest2}

      {{:name, key}, rest2} ->
        {value, rest3} = parse_value(rest2)
        parse_dict(rest3, Map.put(acc, key, value))

      :eof ->
        {acc, <<>>}

      other ->
        raise ArgumentError, "Expected name key in dict, got: #{inspect(other)}"
    end
  end
end
