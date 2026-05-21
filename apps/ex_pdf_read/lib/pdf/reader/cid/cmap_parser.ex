defmodule Pdf.Reader.CID.CMapParser do
  @moduledoc """
  Minimal PostScript subset parser for Adobe predefined CMap files.

  Handles only the operators required for CID lookup:
  `begin/endcodespacerange`, `begin/endcidchar`, `begin/endcidrange`,
  `begin/endnotdefchar`, `begin/endnotdefrange`, `usecmap`.

  All other PostScript content (comments, /CMapName, /CIDSystemInfo,
  /WMode, dict/array literals, dup/def/pop, etc.) is silently skipped.

  Returns a parsed struct compatible with `Pdf.Reader.CID.PredefinedCMap`
  for caching and lookup.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 9.7.5 — Predefined CMaps:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.7.6 — Codespace ranges:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - Adobe Tech Note #5099 — CMap and CIDFont Files Specification:
    https://adobe-type-tools.github.io/font-tech-notes/pdfs/5099.CMapResources.pdf
  - Adobe Tech Note #5014 — CID-Keyed Font Technology Overview:
    https://adobe-type-tools.github.io/font-tech-notes/pdfs/5014.CIDFont_Spec.pdf
  """

  @type cmap :: %{
          cidchar: %{non_neg_integer() => non_neg_integer()},
          cidrange: [{non_neg_integer(), non_neg_integer(), non_neg_integer()}],
          notdef_chars: %{non_neg_integer() => non_neg_integer()},
          notdef_ranges: [{non_neg_integer(), non_neg_integer(), non_neg_integer()}],
          codespaces: %{(1..4) => [{non_neg_integer(), non_neg_integer()}]},
          parent: String.t() | nil
        }

  @empty_cmap %{
    cidchar: %{},
    cidrange: [],
    notdef_chars: %{},
    notdef_ranges: [],
    codespaces: %{},
    parent: nil
  }

  @doc """
  Parse a PostScript CMap text and return a plain map with the extracted
  CID mapping data.

  Returns `{:ok, cmap_fields}` on success or `{:error, reason}` if the
  input is fundamentally unparseable. Unknown or irrelevant tokens are
  silently skipped — this function NEVER raises.

  ## Return map keys

  - `:cidchar` — `%{code_integer => cid_integer}`
  - `:cidrange` — `[{lo, hi, base_cid}]`
  - `:notdef_chars` — `%{code_integer => cid_integer}`
  - `:notdef_ranges` — `[{lo, hi, base_cid}]`
  - `:codespaces` — `%{byte_length => [{lo, hi}]}`, grouped by byte width
  - `:parent` — `String.t() | nil` — name from `usecmap` directive
  """
  @spec parse(text :: binary()) :: {:ok, cmap()} | {:error, term()}
  def parse(text) when is_binary(text) do
    tokens = tokenize(text)
    acc = dispatch(tokens, @empty_cmap)
    {:ok, acc}
  rescue
    e -> {:error, e}
  end

  def parse(_), do: {:error, :not_binary}

  # ---------------------------------------------------------------------------
  # Tokenizer — produces a flat list of tagged tokens
  # ---------------------------------------------------------------------------

  # Known keyword atoms mapped from their string forms
  @keywords %{
    "begincodespacerange" => :begincodespacerange,
    "endcodespacerange" => :endcodespacerange,
    "begincidchar" => :begincidchar,
    "endcidchar" => :endcidchar,
    "begincidrange" => :begincidrange,
    "endcidrange" => :endcidrange,
    "beginnotdefchar" => :beginnotdefchar,
    "endnotdefchar" => :endnotdefchar,
    "beginnotdefrange" => :beginnotdefrange,
    "endnotdefrange" => :endnotdefrange,
    "usecmap" => :usecmap
  }

  # Tokens we can immediately discard (PostScript boilerplate)
  # NOTE: bare identifiers that are NOT keywords and NOT in this list will be
  # emitted as {:name, word} so they can participate in `/NAME usecmap` and
  # `NAME usecmap` patterns. Only truly structural boilerplate is discarded.
  @skip_words ~w(
    dup def pop begin end dict currentdict findresource defineresource
    begincmap endcmap
  )

  @spec tokenize(binary()) :: list()
  defp tokenize(text) do
    tokenize_loop(text, [])
    |> Enum.reverse()
  end

  defp tokenize_loop(<<>>, acc), do: acc

  # Skip comments: % to end of line
  defp tokenize_loop(<<?%, rest::binary>>, acc) do
    rest2 = skip_to_newline(rest)
    tokenize_loop(rest2, acc)
  end

  # Skip whitespace
  defp tokenize_loop(<<c, rest::binary>>, acc) when c in [?\s, ?\t, ?\n, ?\r] do
    tokenize_loop(rest, acc)
  end

  # Hex string <HHHH>
  defp tokenize_loop(<<?<, rest::binary>>, acc) do
    case read_hex_string(rest) do
      {hex_bytes, rest2} ->
        tokenize_loop(rest2, [{:hex, hex_bytes} | acc])

      :error ->
        # skip malformed hex, advance one char
        tokenize_loop(rest, acc)
    end
  end

  # Parenthesised string — skip entirely (track nesting depth)
  defp tokenize_loop(<<?(, rest::binary>>, acc) do
    rest2 = skip_paren_string(rest, 1)
    tokenize_loop(rest2, acc)
  end

  # Array literal [...] — skip
  defp tokenize_loop(<<?[, rest::binary>>, acc) do
    rest2 = skip_bracket(rest, ?[, ?])
    tokenize_loop(rest2, acc)
  end

  # Dict literal <<...>> — skip (the < is already consumed above for hex)
  # This path handles bare { ... } — PS procedure body
  defp tokenize_loop(<<?{, rest::binary>>, acc) do
    rest2 = skip_bracket(rest, ?{, ?})
    tokenize_loop(rest2, acc)
  end

  # Name token: /IDENT
  defp tokenize_loop(<<?/, rest::binary>>, acc) do
    {name, rest2} = read_identifier(rest)
    tokenize_loop(rest2, [{:name, name} | acc])
  end

  # Integer or identifier
  defp tokenize_loop(<<c, _::binary>> = input, acc) when c in ?0..?9 or c == ?- do
    {word, rest} = read_word(input)

    token =
      case Integer.parse(word) do
        {n, ""} -> {:int, n}
        _ -> classify_word(word)
      end

    case token do
      :skip -> tokenize_loop(rest, acc)
      t -> tokenize_loop(rest, [t | acc])
    end
  end

  defp tokenize_loop(<<_c, _::binary>> = input, acc) do
    {word, rest} = read_word(input)

    token = classify_word(word)

    case token do
      :skip -> tokenize_loop(rest, acc)
      t -> tokenize_loop(rest, [t | acc])
    end
  end

  # Read characters up to (but not including) the next newline
  defp skip_to_newline(<<?\n, rest::binary>>), do: rest
  defp skip_to_newline(<<?\r, rest::binary>>), do: rest
  defp skip_to_newline(<<_c, rest::binary>>), do: skip_to_newline(rest)
  defp skip_to_newline(<<>>), do: <<>>

  # Read hex digits inside <...>, return decoded binary
  defp read_hex_string(bin), do: read_hex_string(bin, <<>>)

  defp read_hex_string(<<?>, rest::binary>>, hex_acc) do
    hex_str = String.trim(hex_acc)

    # Pad to even length
    hex_str =
      if rem(byte_size(hex_str), 2) == 1,
        do: hex_str <> "0",
        else: hex_str

    case Base.decode16(hex_str, case: :mixed) do
      {:ok, decoded} -> {decoded, rest}
      :error -> :error
    end
  end

  defp read_hex_string(<<?\n, rest::binary>>, acc), do: read_hex_string(rest, acc)
  defp read_hex_string(<<?\r, rest::binary>>, acc), do: read_hex_string(rest, acc)
  defp read_hex_string(<<?\s, rest::binary>>, acc), do: read_hex_string(rest, acc)
  defp read_hex_string(<<?\t, rest::binary>>, acc), do: read_hex_string(rest, acc)
  defp read_hex_string(<<c, rest::binary>>, acc), do: read_hex_string(rest, <<acc::binary, c>>)
  defp read_hex_string(<<>>, _acc), do: :error

  # Skip a parenthesised string, tracking nesting
  defp skip_paren_string(<<>>, _depth), do: <<>>
  defp skip_paren_string(<<?), rest::binary>>, 1), do: rest
  defp skip_paren_string(<<?), rest::binary>>, depth), do: skip_paren_string(rest, depth - 1)
  defp skip_paren_string(<<?(, rest::binary>>, depth), do: skip_paren_string(rest, depth + 1)
  defp skip_paren_string(<<_c, rest::binary>>, depth), do: skip_paren_string(rest, depth)

  # Skip matched bracket pair, with nesting
  defp skip_bracket(<<>>, _open, _close), do: <<>>

  defp skip_bracket(<<c, rest::binary>>, _open, close) when c == close, do: rest

  defp skip_bracket(<<c, rest::binary>>, open, close) when c == open do
    rest2 = skip_bracket(rest, open, close)
    skip_bracket(rest2, open, close)
  end

  defp skip_bracket(<<_c, rest::binary>>, open, close),
    do: skip_bracket(rest, open, close)

  # Read word: run of non-whitespace, non-special chars
  @word_stop [?\s, ?\t, ?\n, ?\r, ?<, ?>, ?/, ?(, ?), ?[, ?], ?{, ?}, ?%]

  defp read_word(bin), do: read_word(bin, <<>>)

  defp read_word(<<>>, acc), do: {acc, <<>>}

  defp read_word(<<c, _::binary>> = rest, acc) when c in @word_stop, do: {acc, rest}

  defp read_word(<<c, rest::binary>>, acc), do: read_word(rest, <<acc::binary, c>>)

  # Read an identifier (after /)
  defp read_identifier(bin), do: read_word(bin)

  # Classify a bare word
  defp classify_word(word) when word in @skip_words, do: :skip
  defp classify_word(""), do: :skip

  defp classify_word(word) do
    case Map.get(@keywords, word) do
      nil ->
        # Emit unknown identifiers as {:name, word} — required for bare
        # `NAME usecmap` patterns (usecmap without a leading slash).
        {:name, word}

      kw ->
        {:keyword, kw}
    end
  end

  # ---------------------------------------------------------------------------
  # Dispatcher — walks token list and calls handlers when keywords are found
  # ---------------------------------------------------------------------------

  defp dispatch([], acc), do: acc

  # usecmap — look-ahead: NAME usecmap or /NAME usecmap
  # Both produce {:name, name} in the token stream; match the pair.
  defp dispatch([{:name, name}, {:keyword, :usecmap} | rest], acc) do
    dispatch(rest, %{acc | parent: name})
  end

  # Bare usecmap without a preceding name token (malformed or unparseable context) — skip
  defp dispatch([{:keyword, :usecmap} | rest], acc) do
    dispatch(rest, acc)
  end

  # begincodespacerange
  defp dispatch([{:keyword, :begincodespacerange} | rest], acc) do
    {entries, rest2} = collect_until(rest, :endcodespacerange)
    new_codespaces = handle_codespacerange(entries, acc.codespaces)
    dispatch(rest2, %{acc | codespaces: new_codespaces})
  end

  # begincidchar
  defp dispatch([{:keyword, :begincidchar} | rest], acc) do
    {entries, rest2} = collect_until(rest, :endcidchar)
    new_cidchar = handle_cidchar(entries, acc.cidchar)
    dispatch(rest2, %{acc | cidchar: new_cidchar})
  end

  # begincidrange
  defp dispatch([{:keyword, :begincidrange} | rest], acc) do
    {entries, rest2} = collect_until(rest, :endcidrange)
    new_cidrange = handle_cidrange(entries, acc.cidrange)
    dispatch(rest2, %{acc | cidrange: new_cidrange})
  end

  # beginnotdefchar
  defp dispatch([{:keyword, :beginnotdefchar} | rest], acc) do
    {entries, rest2} = collect_until(rest, :endnotdefchar)
    new_notdef = handle_cidchar(entries, acc.notdef_chars)
    dispatch(rest2, %{acc | notdef_chars: new_notdef})
  end

  # beginnotdefrange
  defp dispatch([{:keyword, :beginnotdefrange} | rest], acc) do
    {entries, rest2} = collect_until(rest, :endnotdefrange)
    new_notdef_ranges = handle_cidrange(entries, acc.notdef_ranges)
    dispatch(rest2, %{acc | notdef_ranges: new_notdef_ranges})
  end

  # int token before a begin* — count; skip it
  defp dispatch([{:int, _n} | rest], acc), do: dispatch(rest, acc)

  # lone name token without usecmap following — skip
  defp dispatch([{:name, _} | rest], acc), do: dispatch(rest, acc)

  # anything else — skip
  defp dispatch([_token | rest], acc), do: dispatch(rest, acc)

  # ---------------------------------------------------------------------------
  # Collect tokens between begin* and end* keywords
  # ---------------------------------------------------------------------------

  defp collect_until(tokens, end_keyword) do
    collect_until(tokens, end_keyword, [])
  end

  defp collect_until([], _end_kw, acc), do: {Enum.reverse(acc), []}

  defp collect_until([{:keyword, end_kw} | rest], end_kw, acc) do
    {Enum.reverse(acc), rest}
  end

  defp collect_until([token | rest], end_kw, acc) do
    collect_until(rest, end_kw, [token | acc])
  end

  # ---------------------------------------------------------------------------
  # Operator handlers
  # ---------------------------------------------------------------------------

  # codespacerange: pairs of hex lo/hi, grouped by byte length of lo
  defp handle_codespacerange(tokens, codespaces) do
    pairs = collect_hex_pairs(tokens)

    Enum.reduce(pairs, codespaces, fn {lo_bytes, hi_bytes}, cs ->
      len = byte_size(lo_bytes)
      lo = bytes_to_integer(lo_bytes)
      hi = bytes_to_integer(hi_bytes)
      Map.update(cs, len, [{lo, hi}], fn existing -> existing ++ [{lo, hi}] end)
    end)
  end

  # cidchar: pairs of hex_code, int_cid
  defp handle_cidchar(tokens, cidchar) do
    collect_hex_int_pairs(tokens)
    |> Enum.reduce(cidchar, fn {code_bytes, cid}, map ->
      code = bytes_to_integer(code_bytes)
      Map.put(map, code, cid)
    end)
  end

  # cidrange: triples of hex_lo, hex_hi, int_base_cid
  defp handle_cidrange(tokens, cidrange) do
    collect_hex_hex_int_triples(tokens)
    |> Enum.reduce(cidrange, fn {lo_bytes, hi_bytes, base_cid}, list ->
      lo = bytes_to_integer(lo_bytes)
      hi = bytes_to_integer(hi_bytes)
      list ++ [{lo, hi, base_cid}]
    end)
  end

  # ---------------------------------------------------------------------------
  # Token collection helpers
  # ---------------------------------------------------------------------------

  defp collect_hex_pairs(tokens), do: collect_hex_pairs(tokens, [])
  defp collect_hex_pairs([], acc), do: Enum.reverse(acc)

  defp collect_hex_pairs([{:hex, lo}, {:hex, hi} | rest], acc) do
    collect_hex_pairs(rest, [{lo, hi} | acc])
  end

  # Skip stray int tokens (the N count leaks here sometimes)
  defp collect_hex_pairs([{:int, _} | rest], acc), do: collect_hex_pairs(rest, acc)
  defp collect_hex_pairs([_other | rest], acc), do: collect_hex_pairs(rest, acc)

  defp collect_hex_int_pairs(tokens), do: collect_hex_int_pairs(tokens, [])
  defp collect_hex_int_pairs([], acc), do: Enum.reverse(acc)

  defp collect_hex_int_pairs([{:hex, code}, {:int, cid} | rest], acc) do
    collect_hex_int_pairs(rest, [{code, cid} | acc])
  end

  defp collect_hex_int_pairs([_other | rest], acc), do: collect_hex_int_pairs(rest, acc)

  defp collect_hex_hex_int_triples(tokens), do: collect_hex_hex_int_triples(tokens, [])
  defp collect_hex_hex_int_triples([], acc), do: Enum.reverse(acc)

  defp collect_hex_hex_int_triples([{:hex, lo}, {:hex, hi}, {:int, base} | rest], acc) do
    collect_hex_hex_int_triples(rest, [{lo, hi, base} | acc])
  end

  defp collect_hex_hex_int_triples([_other | rest], acc),
    do: collect_hex_hex_int_triples(rest, acc)

  # ---------------------------------------------------------------------------
  # Byte helpers
  # ---------------------------------------------------------------------------

  defp bytes_to_integer(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn byte, acc -> acc * 256 + byte end)
  end
end
