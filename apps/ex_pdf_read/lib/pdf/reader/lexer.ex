defmodule Pdf.Reader.Lexer do
  @moduledoc """
  PDF binary tokenizer.

  ## Token shapes

      :eof
      {:integer, integer()}
      {:real, float()}
      {:boolean, boolean()}
      :null
      {:name, binary()}          # without leading /
      {:string, binary()}        # literal (...)
      {:hex_string, binary()}    # <...> decoded to bytes
      :array_open  |  :array_close
      :dict_open   |  :dict_close
      {:obj, rest}  |  {:endobj, rest}
      {:stream, rest}  |  {:endstream, rest}
      {:xref, rest}  |  {:trailer, rest}  |  {:startxref, rest}
      {:r, rest}  |  {:f, rest}  |  {:n, rest}

  `next_token/1` returns `{token, rest_binary}` or `:eof`.
  """

  # PDF § 7.2.2 whitespace characters
  @whitespace [0, 9, 10, 12, 13, 32]

  # PDF § 7.2.2 delimiter characters (ASCII codes)
  # ( ) < > [ ] { } / %
  # 40 41 60 62 91 93 123 125 47 37
  @delimiters [40, 41, 60, 62, 91, 93, 123, 125, 47, 37]

  # Hex digit guard — must be defined BEFORE parse_hex_string uses it
  defguardp is_hex(c)
            when (c >= 48 and c <= 57) or (c >= 97 and c <= 102) or (c >= 65 and c <= 70)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns the next token from `binary` together with the unconsumed rest.

  Returns `:eof` when the binary is empty or contains only whitespace/comments.
  """
  @spec next_token(binary()) :: {term(), binary()} | :eof
  def next_token(binary) when is_binary(binary) do
    binary
    |> skip_whitespace_and_comments()
    |> do_next_token()
  end

  @doc """
  Skips all leading whitespace (PDF § 7.2.2: space, tab, LF, CR, FF, NUL).
  """
  @spec skip_whitespace(binary()) :: binary()
  def skip_whitespace(<<c, rest::binary>>) when c in @whitespace, do: skip_whitespace(rest)
  def skip_whitespace(bin), do: bin

  # ---------------------------------------------------------------------------
  # Internal — skip whitespace + comments
  # ---------------------------------------------------------------------------

  defp skip_whitespace_and_comments(<<c, rest::binary>>) when c in @whitespace do
    skip_whitespace_and_comments(rest)
  end

  # 37 = ?%
  defp skip_whitespace_and_comments(<<37, rest::binary>>) do
    rest |> skip_comment_line() |> skip_whitespace_and_comments()
  end

  defp skip_whitespace_and_comments(bin), do: bin

  defp skip_comment_line(<<10, rest::binary>>), do: rest
  defp skip_comment_line(<<13, 10, rest::binary>>), do: rest
  defp skip_comment_line(<<13, rest::binary>>), do: rest
  defp skip_comment_line(<<_, rest::binary>>), do: skip_comment_line(rest)
  defp skip_comment_line(<<>>), do: <<>>

  # ---------------------------------------------------------------------------
  # Internal — dispatch tokenizer
  # ---------------------------------------------------------------------------

  defp do_next_token(<<>>), do: :eof

  # Dict open << — 60 = ?<
  defp do_next_token(<<60, 60, rest::binary>>), do: {:dict_open, rest}

  # Dict close >> — 62 = ?>
  defp do_next_token(<<62, 62, rest::binary>>), do: {:dict_close, rest}

  # Hex string <...>  (must come AFTER << check)
  defp do_next_token(<<60, rest::binary>>) do
    {bytes, rest2} = parse_hex_string(rest, <<>>)
    {{:hex_string, bytes}, rest2}
  end

  # Array open [ — 91
  defp do_next_token(<<91, rest::binary>>), do: {:array_open, rest}

  # Array close ] — 93
  defp do_next_token(<<93, rest::binary>>), do: {:array_close, rest}

  # Name /... — 47 = ?/
  defp do_next_token(<<47, rest::binary>>) do
    {name, rest2} = read_name(rest, <<>>)
    {{:name, name}, rest2}
  end

  # Literal string (...)  — 40 = ?(
  defp do_next_token(<<40, rest::binary>>) do
    {str, rest2} = parse_literal_string(rest, 0, <<>>)
    {{:string, str}, rest2}
  end

  # Numbers — minus, plus, dot, digits
  defp do_next_token(<<c, _::binary>> = bin)
       when c == 45 or c == 43 or c == 46 or (c >= 48 and c <= 57) do
    parse_number(bin)
  end

  # Keywords and booleans — read a word and dispatch
  defp do_next_token(<<c, _::binary>> = bin)
       when (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 do
    {word, rest} = read_word(bin, <<>>)
    map_keyword(word, rest)
  end

  defp do_next_token(<<c, _rest::binary>>) do
    raise ArgumentError,
          "Unexpected byte in PDF stream: #{inspect(<<c>>)} (0x#{Integer.to_string(c, 16)})"
  end

  # ---------------------------------------------------------------------------
  # Keyword / boolean mapping
  # ---------------------------------------------------------------------------

  defp map_keyword("true", rest), do: {{:boolean, true}, rest}
  defp map_keyword("false", rest), do: {{:boolean, false}, rest}
  defp map_keyword("null", rest), do: {:null, rest}
  defp map_keyword("obj", rest), do: {:obj, rest}
  defp map_keyword("endobj", rest), do: {:endobj, rest}
  defp map_keyword("stream", rest), do: {:stream, rest}
  defp map_keyword("endstream", rest), do: {:endstream, rest}
  defp map_keyword("xref", rest), do: {:xref, rest}
  defp map_keyword("trailer", rest), do: {:trailer, rest}
  defp map_keyword("startxref", rest), do: {:startxref, rest}
  defp map_keyword("R", rest), do: {:r, rest}
  defp map_keyword("f", rest), do: {:f, rest}
  defp map_keyword("n", rest), do: {:n, rest}
  defp map_keyword(word, rest), do: {{:keyword, word}, rest}

  # ---------------------------------------------------------------------------
  # Read a bare word (stops at delimiter or whitespace)
  # ---------------------------------------------------------------------------

  defp read_word(<<c, rest::binary>>, acc)
       when (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or
              (c >= 48 and c <= 57) or c == 95 or c == 42 or c == 39 do
    read_word(rest, <<acc::binary, c>>)
  end

  defp read_word(bin, acc), do: {acc, bin}

  # ---------------------------------------------------------------------------
  # Name parsing (after leading / consumed)
  # stops at whitespace or delimiter
  # ---------------------------------------------------------------------------

  # #XX hex escape in name — 35 = ?#
  defp read_name(<<35, h1, h2, rest::binary>>, acc) do
    byte = String.to_integer(<<h1, h2>>, 16)
    read_name(rest, <<acc::binary, byte>>)
  end

  defp read_name(<<c, rest::binary>>, acc) when c not in @whitespace and c not in @delimiters do
    read_name(rest, <<acc::binary, c>>)
  end

  defp read_name(bin, acc), do: {acc, bin}

  # ---------------------------------------------------------------------------
  # Literal string parsing (after leading ( consumed)
  # depth tracks nested unescaped parens per PDF spec § 7.3.4.2
  # 40 = ?(, 41 = ?)
  # ---------------------------------------------------------------------------

  # End of string: ) at depth 0
  defp parse_literal_string(<<41, rest::binary>>, 0, acc), do: {acc, rest}

  # ) at depth > 0 — it's a nested close paren, add it to string
  defp parse_literal_string(<<41, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth - 1, <<acc::binary, 41>>)
  end

  # ( at any depth — nested open paren, add it to string
  defp parse_literal_string(<<40, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth + 1, <<acc::binary, 40>>)
  end

  # Escape sequences — 92 = ?\\
  defp parse_literal_string(<<92, 110, rest::binary>>, depth, acc) do
    # \n
    parse_literal_string(rest, depth, <<acc::binary, 10>>)
  end

  defp parse_literal_string(<<92, 114, rest::binary>>, depth, acc) do
    # \r
    parse_literal_string(rest, depth, <<acc::binary, 13>>)
  end

  defp parse_literal_string(<<92, 116, rest::binary>>, depth, acc) do
    # \t
    parse_literal_string(rest, depth, <<acc::binary, 9>>)
  end

  defp parse_literal_string(<<92, 98, rest::binary>>, depth, acc) do
    # \b
    parse_literal_string(rest, depth, <<acc::binary, 8>>)
  end

  defp parse_literal_string(<<92, 102, rest::binary>>, depth, acc) do
    # \f
    parse_literal_string(rest, depth, <<acc::binary, 12>>)
  end

  # \( — escaped open paren
  defp parse_literal_string(<<92, 40, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, <<acc::binary, 40>>)
  end

  # \) — escaped close paren
  defp parse_literal_string(<<92, 41, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, <<acc::binary, 41>>)
  end

  # \\ — escaped backslash
  defp parse_literal_string(<<92, 92, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, <<acc::binary, 92>>)
  end

  # Octal \ddd
  defp parse_literal_string(<<92, d1, d2, d3, rest::binary>>, depth, acc)
       when d1 >= 48 and d1 <= 55 and d2 >= 48 and d2 <= 55 and d3 >= 48 and d3 <= 55 do
    byte = (d1 - 48) * 64 + (d2 - 48) * 8 + (d3 - 48)
    parse_literal_string(rest, depth, <<acc::binary, byte>>)
  end

  defp parse_literal_string(<<92, d1, d2, rest::binary>>, depth, acc)
       when d1 >= 48 and d1 <= 55 and d2 >= 48 and d2 <= 55 do
    byte = (d1 - 48) * 8 + (d2 - 48)
    parse_literal_string(rest, depth, <<acc::binary, byte>>)
  end

  defp parse_literal_string(<<92, d1, rest::binary>>, depth, acc) when d1 >= 48 and d1 <= 55 do
    byte = d1 - 48
    parse_literal_string(rest, depth, <<acc::binary, byte>>)
  end

  # Escaped newlines: \<CR><LF>, \<CR>, \<LF> → ignored (line continuation)
  defp parse_literal_string(<<92, 13, 10, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, acc)
  end

  defp parse_literal_string(<<92, 13, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, acc)
  end

  defp parse_literal_string(<<92, 10, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, acc)
  end

  # Unknown escape — ignore backslash per spec
  defp parse_literal_string(<<92, c, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, <<acc::binary, c>>)
  end

  # Regular character
  defp parse_literal_string(<<c, rest::binary>>, depth, acc) do
    parse_literal_string(rest, depth, <<acc::binary, c>>)
  end

  defp parse_literal_string(<<>>, _depth, acc), do: {acc, <<>>}

  # ---------------------------------------------------------------------------
  # Hex string parsing (after leading < consumed)
  # 62 = ?>
  # ---------------------------------------------------------------------------

  defp parse_hex_string(<<62, rest::binary>>, acc), do: {acc, rest}

  defp parse_hex_string(<<c, rest::binary>>, acc) when c in @whitespace do
    parse_hex_string(rest, acc)
  end

  defp parse_hex_string(<<h1, h2, rest::binary>>, acc) when is_hex(h1) and is_hex(h2) do
    byte = String.to_integer(<<h1, h2>>, 16)
    parse_hex_string(rest, <<acc::binary, byte>>)
  end

  # Odd final nibble — pad with 0 (62 = ?>)
  defp parse_hex_string(<<h1, 62, rest::binary>>, acc) when is_hex(h1) do
    byte = String.to_integer(<<h1, ?0>>, 16)
    {<<acc::binary, byte>>, rest}
  end

  defp parse_hex_string(<<>>, acc), do: {acc, <<>>}

  # ---------------------------------------------------------------------------
  # Number parsing
  # ---------------------------------------------------------------------------

  defp parse_number(bin) do
    {num_str, rest} = read_number_chars(bin, <<>>)

    if String.contains?(num_str, ".") do
      {{:real, parse_float(num_str)}, rest}
    else
      {{:integer, String.to_integer(num_str)}, rest}
    end
  end

  # 45=-  43=+  46=.  48-57=0-9
  defp read_number_chars(<<c, rest::binary>>, acc)
       when (c >= 48 and c <= 57) or c == 46 or c == 45 or c == 43 do
    if (c == 45 or c == 43) and byte_size(acc) > 0 do
      {acc, <<c, rest::binary>>}
    else
      read_number_chars(rest, <<acc::binary, c>>)
    end
  end

  defp read_number_chars(bin, acc), do: {acc, bin}

  defp parse_float(str) do
    # Handle leading dot: ".5" → "0.5"
    str = if String.starts_with?(str, "."), do: "0" <> str, else: str
    # Handle trailing dot: "1." → "1.0"
    str = if String.ends_with?(str, "."), do: str <> "0", else: str
    # Handle sign + leading dot: "+.5" or "-.5"
    str =
      cond do
        String.starts_with?(str, "+.") -> "+" <> "0" <> String.slice(str, 1..-1//1)
        String.starts_with?(str, "-.") -> "-" <> "0" <> String.slice(str, 1..-1//1)
        true -> str
      end

    String.to_float(str)
  end
end
