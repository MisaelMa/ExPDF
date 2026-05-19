defmodule Pdf.Reader.ContentStream do
  @moduledoc """
  PDF content stream interpreter for text and image extraction.

  Spec reference: PDF 1.7 § 9.4 (text operators), § 8.4 (general graphics state),
  § 8.8 (XObjects), § 9.4.5 (Tf — set text font and size).

  ## Phase 1.1 additions

  - **`font_decoders:` opt** — `%{font_name => decoder_fn}`. When provided, the
    active decoder is swapped on every `Tf` operator. After `Tf /F1 12` the
    decoder for `"F1"` is activated; subsequent `Tj`/`TJ`/`'`/`"` calls use it.
    When a font name is not in the map, the `default_decoder` (the second argument
    to `interpret/3`) is used instead.
    Spec reference: PDF 1.7 § 9.4.5 (Tf operator).

  - **`Do` image event shape change** — event is now
    `{:image, %{name: name, ctm: {a, b, c, d, e, f}}}` (full 6-tuple of the CTM
    at `Do` time). The `:x` and `:y` fields (formerly present directly) are derived
    from `ctm.e` and `ctm.f` by the caller (`Pdf.Reader.extract_page_images/3`).

  ## Phase 1 scope

  Interprets 15 operators sufficient for text and image extraction:
  `BT`, `ET`, `Tf`, `Tj`, `TJ`, `'`, `"`, `Td`, `TD`, `Tm`, `T*`,
  `cm`, `q`, `Q`, `Do`.

  All other operators (path construction, painting, color, shading, inline images,
  marked content, compatibility) are **silently consumed** — their operands are
  cleared from the operand stack and execution continues. This keeps the interpreter
  robust to real-world content streams without crashing.

  ## API

      interpret(content_binary, decoder) :: {:ok, [event]} | {:error, term}
      interpret(content_binary, decoder, opts) :: {:ok, [event]} | {:error, term}

  Where `decoder :: (bytes :: binary) -> {text :: String.t(), unresolved :: list()}`.

  ### Options

  - `:xobjects` — `%{name :: binary => {:ref, n, g} | inline_dict | :image | :form}`.
    Phase 3 (Form recursion): the recommended shape is `%{name => raw_ref}` — the
    interpreter classifies on demand by resolving the XObject and inspecting
    `/Subtype`. The legacy `:image | :form` atoms remain accepted by the public
    `interpret/3` path (which does NOT recurse into Forms) for backward-compat.
  - `:font_decoders` — `%{font_name :: binary => decoder_fn}` — per-font decoder map.
    See Phase 1.1 additions above. Default: `%{}`.

  ## Events

  - `{:text, %{text: String.t(), unresolved: list(), x: float, y: float, font: binary, size: float}}`
  - `{:image, %{name: binary, ctm: {float, float, float, float, float, float}}}` — Phase 1.1
  - `{:deferred, :form_xobject, name :: binary}` — emitted only on the legacy `interpret/3`
    path (no doc threaded). The recursive path in `do_interpret_with_doc/5` REPLACES
    deferred events with the actual recursed Form content.
  - `{:cycle_detected, {n, g}}` — Phase 3: emitted when a Form XObject self-references
    or transitively cycles. Dropped by the reader facade's `events_to_text_runs/2`.
  - `{:max_depth_exceeded, {n, g}}` — Phase 3: emitted when recursion would exceed
    `@max_form_depth` (8). Dropped by the reader facade.

  ## Position math

  Absolute position of a glyph run start:

      M_render = Tm × CTM
      x = M_render.e, y = M_render.f

  Spec: PDF 1.7 § 8.3.3 (row-vector convention), § 9.4.4 (text advance).

  ## Glyph advance (§ 9.4.4)

  Text-matrix advance uses the full PDF § 9.4.4 formula per glyph:

      tx = ((w/1000 - Tj_kern) * Tfs + Tc + Tw_if_space) * Th

  Where `w` comes from the active font's `widths_fn` closure (set by `Tf`).
  Fonts without embedded `/Widths` produce `w=0`; advance is then driven
  only by `Tc`/`Tw`/`Tj_kern` (documented gap for Standard-14 fonts).

  Position of the START of each run is exact (derived from Tm at call time).

  ## Unknown operator strategy

  When an unrecognized operator is encountered, the entire operand stack is cleared
  (per PDF spec § 7.8.2 which states conforming readers should process what they can).
  This is the same strategy used by most major PDF parsers (e.g. pdfminer-six, pdf.js).

  ## Spec references

  - PDF 1.7 (ISO 32000-1) — Adobe free mirror:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
    - § 7.8.2 — Content streams (unknown operator strategy)
    - § 8.3.3 — Coordinate Systems / Matrix Math
    - § 8.4 — General Graphics State (`q`, `Q`, `cm`)
    - § 8.8 — External Objects (`Do` operator)
    - § 8.10 — Form XObjects (recursion target)
    - § 8.10.2 — Form Dictionaries (`/Matrix`, `/BBox`, `/Resources`)
    - § 9.4 — Text Operators (BT/ET/Tf/Tj/TJ/'/"/Td/TD/Tm/T*)
    - § 9.4.4 — Text advance and Tm update
    - § 9.4.5 — Text State (Tf operator)
  - Mozilla pdf.js `src/core/evaluator.js` (Apache-2.0 reference impl):
    https://github.com/mozilla/pdf.js/blob/master/src/core/evaluator.js
  - pdfminer-six `pdfminer/pdfinterp.py` (MIT reference impl):
    https://github.com/pdfminer/pdfminer.six/blob/master/pdfminer/pdfinterp.py
  """

  alias Pdf.Reader.GraphicsState

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  # Maximum form recursion depth (R-FX10). Not configurable at runtime.
  @max_form_depth 8

  # ---------------------------------------------------------------------------
  # Semi-public helpers — used by tests only; not part of the external contract.
  # Phase 5 will formalise do_interpret_with_doc/5 as the private entry point
  # called by reader.ex extract_page_runs/3.
  # ---------------------------------------------------------------------------

  @doc false
  @spec do_interpret_with_doc(
          binary(),
          (binary() -> {String.t(), list()}),
          keyword(),
          Pdf.Reader.Document.t(),
          map()
        ) :: {:ok, [event()], Pdf.Reader.Document.t()} | {:error, term()}
  def do_interpret_with_doc(content_bytes, default_decoder, opts, doc, page_resources) do
    do_interpret_with_doc(
      content_bytes,
      default_decoder,
      opts,
      doc,
      page_resources,
      MapSet.new(),
      0
    )
  end

  @doc false
  @spec do_interpret_with_doc(
          binary(),
          (binary() -> {String.t(), list()}),
          keyword(),
          Pdf.Reader.Document.t(),
          map(),
          MapSet.t(),
          non_neg_integer()
        ) :: {:ok, [event()], Pdf.Reader.Document.t()} | {:error, term()}
  def do_interpret_with_doc(
        content_bytes,
        default_decoder,
        opts,
        doc,
        page_resources,
        visited,
        depth
      ) do
    xobjects = Keyword.get(opts, :xobjects, %{})
    font_decoders = Keyword.get(opts, :font_decoders, %{})
    font_widths = Keyword.get(opts, :font_widths, %{})

    state = %{
      gs: GraphicsState.new(),
      in_text: false,
      operands: [],
      events: [],
      xobjects: xobjects,
      default_decoder: default_decoder,
      font_decoders: font_decoders,
      font_widths: font_widths,
      decoder: default_decoder,
      doc: doc,
      page_resources: page_resources,
      visited: visited,
      depth: depth
    }

    result = tokenize_and_run(content_bytes, state)
    {:ok, Enum.reverse(result.events), result.doc}
  rescue
    e -> {:error, {:content_stream_error, Exception.message(e)}}
  end

  # ---------------------------------------------------------------------------
  # Test-accessible helpers (Phase 4 unit tests call these directly).
  # Phase 5 will keep these private after the public entry points are finalised.
  # ---------------------------------------------------------------------------

  @doc false
  def resolve_form_resources(doc, form_dict) do
    case Map.get(form_dict, "Resources") do
      nil ->
        {:ok, %{}, doc}

      {:ref, _, _} = ref ->
        case Pdf.Reader.ObjectResolver.resolve(doc, ref) do
          {:ok, resources, doc1} when is_map(resources) -> {:ok, resources, doc1}
          {:ok, _other, doc1} -> {:ok, %{}, doc1}
          {:error, _} = err -> err
        end

      resources when is_map(resources) ->
        {:ok, resources, doc}

      _ ->
        {:ok, %{}, doc}
    end
  end

  @doc false
  def merge_resources(page_resources, form_resources) do
    Map.merge(page_resources, form_resources)
  end

  @doc false
  def decode_form_stream({:stream, dict, raw_bytes}) do
    filter = Map.get(dict, "Filter")
    decode_parms = Map.get(dict, "DecodeParms")

    if is_nil(filter) do
      {:ok, raw_bytes}
    else
      Pdf.Reader.Filter.apply_chain(raw_bytes, filter, decode_parms || %{})
    end
  end

  @doc false
  def build_xobject_refs(resources) do
    case Map.get(resources, "XObject") do
      nil -> %{}
      xobjects when is_map(xobjects) -> xobjects
      _ -> %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @type decoder :: (binary() -> {String.t(), list()})

  @type text_event ::
          {:text,
           %{
             text: String.t(),
             unresolved: list(),
             x: float(),
             y: float(),
             font: nil | binary(),
             size: float()
           }}

  @type image_event ::
          {:image, %{name: binary(), ctm: {float(), float(), float(), float(), float(), float()}}}

  @type deferred_event :: {:deferred, :form_xobject, binary()}

  @type guard_event ::
          {:cycle_detected, {pos_integer(), non_neg_integer()}}
          | {:max_depth_exceeded, {pos_integer(), non_neg_integer()}}

  @type event :: text_event() | image_event() | deferred_event() | guard_event()

  @doc """
  Interprets a PDF content stream binary, emitting text and image events.

  `decoder` is called for every string operand (Tj, TJ, etc.) and must
  return `{decoded_utf8_text, unresolved_list}`.

  Options:
  - `:xobjects` — `%{name => :image | :form}` for `Do` operator dispatch.
  """
  @spec interpret(binary(), decoder(), keyword()) :: {:ok, [event()]} | {:error, term()}
  def interpret(binary, decoder, opts \\ []) when is_binary(binary) and is_function(decoder, 1) do
    xobjects = Keyword.get(opts, :xobjects, %{})
    font_decoders = Keyword.get(opts, :font_decoders, %{})

    font_widths = Keyword.get(opts, :font_widths, %{})

    # R-FX6, R-FX12, R-FX16: new fields added with safe defaults so all existing
    # callers that do not pass doc: continue to behave exactly as before.
    state = %{
      gs: GraphicsState.new(),
      in_text: false,
      operands: [],
      events: [],
      xobjects: xobjects,
      default_decoder: decoder,
      font_decoders: font_decoders,
      font_widths: font_widths,
      decoder: decoder,
      # Form XObject recursion fields — nil/empty defaults preserve legacy behaviour
      doc: nil,
      page_resources: %{},
      visited: MapSet.new(),
      depth: 0
    }

    result = tokenize_and_run(binary, state)
    {:ok, Enum.reverse(result.events)}
  rescue
    e -> {:error, {:content_stream_error, Exception.message(e)}}
  end

  # ---------------------------------------------------------------------------
  # Tokenizer + interpreter loop
  # ---------------------------------------------------------------------------

  defp tokenize_and_run(binary, state) do
    case next_token(binary) do
      :done ->
        state

      {:token, token, rest} ->
        new_state = dispatch(token, state)
        tokenize_and_run(rest, new_state)
    end
  end

  # ---------------------------------------------------------------------------
  # Tokenizer: next_token/1
  # Returns {:token, term, rest_binary} or :done
  #
  # Token types:
  #   {:operator, binary}        — operator keyword
  #   {:integer, integer}        — integer operand
  #   {:float, float}            — real operand
  #   {:string, binary}          — literal string (...)
  #   {:hex_string, binary}      — hex string <...>
  #   {:name, binary}            — /Name
  #   :array_start               — [
  #   :array_end                 — ]
  # ---------------------------------------------------------------------------

  defp next_token(<<>>), do: :done

  # Skip whitespace (space, tab, CR, LF, form feed, null)
  defp next_token(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r, ?\n, ?\f, 0] do
    next_token(rest)
  end

  # Comments: % until EOL
  defp next_token(<<?%, rest::binary>>) do
    skip_to = :binary.match(rest, ["\n", "\r"])

    case skip_to do
      {pos, _} -> next_token(binary_part(rest, pos, byte_size(rest) - pos))
      :nomatch -> :done
    end
  end

  # Array delimiters
  defp next_token(<<?[, rest::binary>>), do: {:token, :array_start, rest}
  defp next_token(<<?], rest::binary>>), do: {:token, :array_end, rest}

  # Dict delimiters (skip — we don't need them in content streams)
  defp next_token(<<?<, ?<, rest::binary>>) do
    # Skip dict in content stream (unusual but safe)
    skip_dict(rest)
  end

  # Hex string: <hexdigits>
  defp next_token(<<?<, rest::binary>>) do
    case :binary.match(rest, ">") do
      {pos, _} ->
        hex_str = binary_part(rest, 0, pos)
        after_gt = binary_part(rest, pos + 1, byte_size(rest) - pos - 1)
        decoded = Base.decode16!(String.replace(hex_str, ~r/\s/, ""), case: :mixed)
        {:token, {:hex_string, decoded}, after_gt}

      :nomatch ->
        :done
    end
  end

  # Literal string: (...)
  defp next_token(<<?(, rest::binary>>) do
    {str, after_str} = read_literal_string(rest, 0, [])
    {:token, {:string, str}, after_str}
  end

  # Name: /Name
  defp next_token(<<?/, rest::binary>>) do
    {name, after_name} = read_name(rest, [])
    {:token, {:name, name}, after_name}
  end

  # Number: integer or float (including negative)
  defp next_token(<<c, _::binary>> = bin) when c in ?0..?9 or c == ?- or c == ?+ or c == ?. do
    {num_str, rest} = read_number(bin, [])
    token = parse_number(num_str)
    {:token, token, rest}
  end

  # Operator keyword: sequences of letters + special chars *, ', "
  defp next_token(<<c, _::binary>> = bin) when c in ?a..?z or c in ?A..?Z do
    {op, rest} = read_operator(bin, [])
    {:token, {:operator, op}, rest}
  end

  # Apostrophe operator (')
  defp next_token(<<?', rest::binary>>), do: {:token, {:operator, "'"}, rest}

  # Double-quote operator (")
  defp next_token(<<?", rest::binary>>), do: {:token, {:operator, "\""}, rest}

  # Unknown characters — skip
  defp next_token(<<_, rest::binary>>), do: next_token(rest)

  # Read a literal string, handling nested parens and backslash escapes.
  defp read_literal_string(<<>>, _depth, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), <<>>}

  defp read_literal_string(<<?\\, c, rest::binary>>, depth, acc) do
    escaped =
      case c do
        ?n -> "\n"
        ?r -> "\r"
        ?t -> "\t"
        ?b -> "\b"
        ?f -> "\f"
        ?( -> "("
        ?) -> ")"
        ?\\ -> "\\"
        _ -> <<c>>
      end

    read_literal_string(rest, depth, [escaped | acc])
  end

  defp read_literal_string(<<?(, rest::binary>>, depth, acc) do
    read_literal_string(rest, depth + 1, ["(" | acc])
  end

  defp read_literal_string(<<?), rest::binary>>, 0, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  defp read_literal_string(<<?), rest::binary>>, depth, acc) do
    read_literal_string(rest, depth - 1, [")" | acc])
  end

  defp read_literal_string(<<c, rest::binary>>, depth, acc) do
    read_literal_string(rest, depth, [<<c>> | acc])
  end

  # Read a /Name token (until delimiter)
  defp read_name(<<>>, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), <<>>}

  defp read_name(<<c, rest::binary>>, acc)
       when c in [?\s, ?\t, ?\r, ?\n, ?\f, ?/, ?<, ?>, ?[, ?], ?(, ?), ?{, ?}] do
    {IO.iodata_to_binary(Enum.reverse(acc)), <<c, rest::binary>>}
  end

  defp read_name(<<c, rest::binary>>, acc), do: read_name(rest, [<<c>> | acc])

  # Read operator characters
  defp read_operator(<<>>, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), <<>>}

  defp read_operator(<<c, rest::binary>>, acc)
       when c in ?a..?z or c in ?A..?Z or c == ?* do
    read_operator(rest, [<<c>> | acc])
  end

  defp read_operator(bin, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), bin}

  # Read a number string
  defp read_number(<<>>, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), <<>>}

  defp read_number(<<c, rest::binary>>, acc)
       when c in ?0..?9 or c == ?. or c == ?- or c == ?+ or c == ?e or c == ?E do
    read_number(rest, [<<c>> | acc])
  end

  defp read_number(bin, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), bin}

  defp parse_number(str) do
    if String.contains?(str, ".") do
      {:float, String.to_float(str)}
    else
      {:integer, String.to_integer(str)}
    end
  rescue
    _ ->
      # Malformed number — default to 0
      {:integer, 0}
  end

  # Skip dict value in content stream (unusual; just skip to >>)
  defp skip_dict(binary) do
    case :binary.match(binary, ">>") do
      {pos, len} ->
        rest = binary_part(binary, pos + len, byte_size(binary) - pos - len)
        next_token(rest)

      :nomatch ->
        :done
    end
  end

  # ---------------------------------------------------------------------------
  # Dispatch: handle token against current interpreter state
  # ---------------------------------------------------------------------------

  # Non-operator tokens: push onto operand stack
  defp dispatch({:integer, _} = tok, state), do: push_operand(state, tok)
  defp dispatch({:float, _} = tok, state), do: push_operand(state, tok)
  defp dispatch({:string, _} = tok, state), do: push_operand(state, tok)
  defp dispatch({:hex_string, _} = tok, state), do: push_operand(state, tok)
  defp dispatch({:name, _} = tok, state), do: push_operand(state, tok)
  defp dispatch(:array_start, state), do: handle_array(state)
  # handled inside handle_array
  defp dispatch(:array_end, state), do: state

  # Operators
  defp dispatch({:operator, op}, state), do: handle_operator(op, state)

  defp push_operand(%{operands: ops} = state, token) do
    %{state | operands: [token | ops]}
  end

  # ---------------------------------------------------------------------------
  # Array accumulation
  # After seeing [ we collect tokens until ] and push the array as one operand.
  # ---------------------------------------------------------------------------

  defp handle_array(state) do
    # Signal we're building an array; handled by collect_array in tokenize loop.
    # We'll re-implement by reading tokens in a nested loop.
    # NOTE: since tokenize_and_run feeds one token at a time, we need a different strategy.
    # For simplicity: mark state with :building_array and accumulate in a list field.
    # Actually, simpler: read the array inline during tokenization.
    # But our current architecture passes state token-by-token.
    # Solution: push a sentinel :array_open, later handle_operator pops until sentinel.
    %{state | operands: [:array_open | state.operands]}
  end

  # ---------------------------------------------------------------------------
  # Operator handlers
  # ---------------------------------------------------------------------------

  # BT — begin text object
  defp handle_operator("BT", %{gs: gs} = state) do
    # Reset Tm and Tlm to identity
    new_gs = %{gs | tm: @identity, tlm: @identity}
    %{state | gs: new_gs, in_text: true, operands: []}
  end

  # ET — end text object
  defp handle_operator("ET", state) do
    %{state | in_text: false, operands: []}
  end

  # Tf — set font and size; swap active decoder from font_decoders map;
  #      set widths_fn from font_widths map (§ 9.4.4, § 9.4.5)
  defp handle_operator(
         "Tf",
         %{
           gs: gs,
           font_decoders: font_decoders,
           default_decoder: default_decoder
         } = state
       ) do
    {font_name, font_size, rest_ops} = pop2(state.operands)
    size = to_float(font_size)
    name = to_name(font_name)
    new_decoder = Map.get(font_decoders, name, default_decoder)
    # widths_fn: look up from font_widths map (nil if font not present)
    font_widths = Map.get(state, :font_widths, %{})
    new_widths_fn = Map.get(font_widths, name, nil)
    new_gs = %{gs | font: name, font_size: size, widths_fn: new_widths_fn}
    %{state | gs: new_gs, operands: rest_ops, decoder: new_decoder}
  end

  # Tc — set character spacing (§ 9.4.1)
  defp handle_operator("Tc", %{gs: gs} = state) do
    {spacing, rest_ops} = pop1(state.operands)
    new_gs = %{gs | char_spacing: to_float(spacing)}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # Tw — set word spacing (§ 9.4.1)
  defp handle_operator("Tw", %{gs: gs} = state) do
    {spacing, rest_ops} = pop1(state.operands)
    new_gs = %{gs | word_spacing: to_float(spacing)}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # Tz — set horizontal scaling (§ 9.4.1); argument is percentage (e.g. 100 = normal)
  defp handle_operator("Tz", %{gs: gs} = state) do
    {scale, rest_ops} = pop1(state.operands)
    # Store as-is (100 = 100%); advance_tm divides by 100 to get Th
    new_gs = %{gs | horizontal_scaling: to_float(scale)}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # TL — set leading (§ 9.4.1)
  defp handle_operator("TL", %{gs: gs} = state) do
    {leading, rest_ops} = pop1(state.operands)
    new_gs = %{gs | leading: to_float(leading)}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # Tj — show string
  defp handle_operator("Tj", %{in_text: false} = state) do
    %{state | operands: []}
  end

  defp handle_operator("Tj", %{gs: gs, decoder: decoder, events: events} = state) do
    {str_token, rest_ops} = pop1(state.operands)
    bytes = token_bytes(str_token)
    {text, unresolved} = decoder.(bytes)
    {x, y} = absolute_position(gs)

    event =
      {:text,
       %{text: text, unresolved: unresolved, x: x, y: y, font: gs.font, size: gs.font_size}}

    new_gs = advance_tm(gs, bytes)
    %{state | gs: new_gs, operands: rest_ops, events: [event | events]}
  end

  # TJ — show text array
  defp handle_operator("TJ", %{in_text: false} = state) do
    %{state | operands: []}
  end

  defp handle_operator("TJ", %{gs: gs, decoder: decoder, events: events} = state) do
    {array, rest_ops} = pop_array(state.operands)
    {new_gs, new_events} = process_tj_array(array, gs, decoder, events)
    %{state | gs: new_gs, operands: rest_ops, events: new_events}
  end

  # ' (apostrophe) — T* + Tj
  defp handle_operator("'", state) do
    state_after_tstar = apply_tstar(state)
    handle_operator("Tj", state_after_tstar)
  end

  # " (double quote) — set Tw, Tc, then '
  defp handle_operator("\"", state) do
    {aw, ac, str_tok, rest_ops} = pop3_with_str(state.operands)

    state2 = %{
      state
      | operands: [str_tok | rest_ops],
        gs: %{state.gs | word_spacing: to_float(aw), char_spacing: to_float(ac)}
    }

    handle_operator("'", state2)
  end

  # Td — move text position
  defp handle_operator("Td", %{gs: gs} = state) do
    {tx, ty, rest_ops} = pop2(state.operands)
    new_gs = apply_td(gs, to_float(tx), to_float(ty))
    %{state | gs: new_gs, operands: rest_ops}
  end

  # TD — set leading and move text position
  defp handle_operator("TD", %{gs: gs} = state) do
    {tx, ty, rest_ops} = pop2(state.operands)
    tx_f = to_float(tx)
    ty_f = to_float(ty)
    new_gs = %{apply_td(gs, tx_f, ty_f) | leading: -ty_f}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # Tm — set text matrix and line matrix
  defp handle_operator("Tm", %{gs: gs} = state) do
    {a, b, c, d, e, f, rest_ops} = pop6(state.operands)
    matrix = {to_float(a), to_float(b), to_float(c), to_float(d), to_float(e), to_float(f)}
    new_gs = %{gs | tm: matrix, tlm: matrix}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # T* — move to next line
  defp handle_operator("T*", state) do
    %{state | gs: apply_tstar_gs(state.gs), operands: []}
  end

  # cm — modify CTM
  defp handle_operator("cm", %{gs: gs} = state) do
    {a, b, c, d, e, f, rest_ops} = pop6(state.operands)
    m = {to_float(a), to_float(b), to_float(c), to_float(d), to_float(e), to_float(f)}
    new_ctm = GraphicsState.multiply(m, gs.ctm)
    new_gs = %{gs | ctm: new_ctm}
    %{state | gs: new_gs, operands: rest_ops}
  end

  # q — push graphics state
  defp handle_operator("q", %{gs: gs} = state) do
    %{state | gs: GraphicsState.push(gs), operands: []}
  end

  # Q — pop graphics state
  defp handle_operator("Q", %{gs: gs} = state) do
    %{state | gs: GraphicsState.pop(gs), operands: []}
  end

  # Do — invoke XObject
  # Phase 1.1 (legacy, doc: nil): image event carries full CTM tuple; form → deferred.
  # Phase 3 (doc: non-nil): on-demand classification via Subtype resolution.
  defp handle_operator("Do", %{xobjects: xobjects, gs: gs} = state) do
    {name_tok, rest_ops} = pop1(state.operands)
    name = to_name(name_tok)
    state1 = %{state | operands: rest_ops}

    cond do
      # Legacy path: doc is nil — keep Phase 1 behaviour (R-FX18 backward compat)
      state1.doc == nil ->
        legacy_do(state1, name, Map.get(xobjects, name, :form), gs)

      # New path: ref-based xobject — classify and dispatch on demand
      is_tuple(Map.get(xobjects, name)) and elem(Map.get(xobjects, name), 0) == :ref ->
        classify_and_dispatch(state1, Map.get(xobjects, name), name)

      # Inline dict xobject (uncommon but valid)
      is_map(Map.get(xobjects, name)) ->
        classify_and_dispatch_inline(state1, Map.get(xobjects, name), name)

      # Name not found in xobjects — skip silently (R-FX20)
      true ->
        state1
    end
  end

  # w, J, j, M, d, ri, i — graphics state operators (clear stack)
  defp handle_operator(op, state)
       when op in ["w", "J", "j", "M", "ri", "i", "gs", "g", "G", "cs", "CS"] do
    %{state | operands: []}
  end

  # All other operators — clear operand stack and continue (safe fallback)
  defp handle_operator(_unknown_op, state) do
    %{state | operands: []}
  end

  # ---------------------------------------------------------------------------
  # Do-handler private helpers (Phase 3)
  # ---------------------------------------------------------------------------

  # Legacy Do handler (doc: nil path) — preserves Phase 1 behaviour (R-FX16, R-FX18)
  defp legacy_do(state, name, :image, gs) do
    emit_event(state, {:image, %{name: name, ctm: gs.ctm}})
  end

  defp legacy_do(state, name, _type, _gs) do
    # :form or any other type → emit deferred marker (Phase 1 behaviour)
    emit_event(state, {:deferred, :form_xobject, name})
  end

  # On-demand classification for ref-based XObjects (doc: non-nil)
  defp classify_and_dispatch(state, {:ref, n, g} = ref, name) do
    cond do
      # R-FX7 / R-FX8: cycle check FIRST — before any resolution attempt
      MapSet.member?(state.visited, {n, g}) ->
        emit_event(state, {:cycle_detected, {n, g}})

      # R-FX11: depth cap check — before resolution
      state.depth >= @max_form_depth ->
        emit_event(state, {:max_depth_exceeded, {n, g}})

      true ->
        case Pdf.Reader.ObjectResolver.resolve(state.doc, ref) do
          {:ok, {:stream, dict, _bytes} = stream, doc1} ->
            state1 = %{state | doc: doc1}
            dispatch_xobject(state1, ref, dict, stream, name)

          _ ->
            # Non-stream or resolution failure → skip silently (R-FX20)
            state
        end
    end
  end

  # On-demand classification for inline dicts
  defp classify_and_dispatch_inline(state, dict, name) do
    case Map.get(dict, "Subtype") do
      {:name, "Image"} ->
        emit_event(state, {:image, %{name: name, ctm: state.gs.ctm}})

      {:name, "Form"} ->
        # Inline form streams are unusual; treat as stream if bytes available
        state

      _ ->
        # Pattern, PS, or other — skip silently (R-FX22)
        state
    end
  end

  # Dispatch XObject by Subtype (R-FX1, R-FX13, R-FX22)
  defp dispatch_xobject(state, ref, dict, stream, name) do
    case Map.get(dict, "Subtype") do
      {:name, "Image"} ->
        emit_event(state, {:image, %{name: name, ctm: state.gs.ctm}})

      {:name, "Form"} ->
        recurse_into_form(state, ref, dict, stream)

      _ ->
        # Pattern XObject, PS XObject, or unknown — skip silently (R-FX22)
        state
    end
  end

  # Emit a single event into the state's event list
  defp emit_event(%{events: events} = state, event) do
    %{state | events: [event | events]}
  end

  # Recurse into a Form XObject (R-FX1–R-FX5, R-FX9, R-FX12, R-FX13)
  defp recurse_into_form(state, {:ref, n, g}, form_dict, form_stream) do
    saved_gs = state.gs

    # R-FX2: apply Form's /Matrix to parent CTM
    form_matrix = parse_matrix(Map.get(form_dict, "Matrix")) || @identity
    form_ctm = GraphicsState.multiply(form_matrix, saved_gs.ctm)

    # R-FX4: resolve and merge Form's /Resources
    case resolve_form_resources(state.doc, form_dict) do
      {:ok, form_resources, doc1} ->
        merged_resources = merge_resources(state.page_resources, form_resources)

        # R-FX5: build per-Form font decoders (cache hits via Document.cache).
        # R-2: build_decoders_for_resources returns 4-tuple; font_failures are
        # discarded here because the page-level log_font_failures already handles
        # page-numbered logging. Form XObject font failures are silently skipped
        # (fallback decoder installed by build_decoders_for_resources in recover mode).
        case Pdf.Reader.Font.build_decoders_for_resources(merged_resources, doc1) do
          {:ok, form_font_decoders, _font_failures, doc2} ->
            # Build per-Form font widths closures (§ 9.4.4); mirrors decoder build above.
            {form_font_widths, doc3} =
              case Pdf.Reader.Font.Widths.build_widths_for_resources(merged_resources, doc2) do
                {:ok, widths_map, updated_doc} -> {widths_map, updated_doc}
                {:error, _} -> {%{}, doc2}
              end

            # R-FX1: decode form stream through filter chain
            case decode_form_stream(form_stream) do
              {:ok, form_bytes} ->
                # R-FX9 / R-FX12: build child state with visited+depth threading
                child_state = %{
                  state
                  | gs: %{saved_gs | ctm: form_ctm},
                    doc: doc3,
                    page_resources: merged_resources,
                    font_decoders: form_font_decoders,
                    font_widths: form_font_widths,
                    decoder: state.default_decoder,
                    visited: MapSet.put(state.visited, {n, g}),
                    depth: state.depth + 1,
                    xobjects: build_xobject_refs(merged_resources),
                    operands: [],
                    in_text: false,
                    events: []
                }

                # Recurse: interpret the Form's content stream
                child_result = tokenize_and_run(form_bytes, child_state)
                doc3 = child_result.doc

                # R-FX3: restore parent gs; append child events in document order (R-FX1).
                # Both state.events and child_result.events are in reverse-accumulation order
                # (newest first). To preserve document order when the caller does
                # Enum.reverse(result.events), child events must be prepended to parent events:
                #   final_reversed = child_reversed ++ parent_reversed
                #   Enum.reverse(final_reversed) = parent_events ++ child_events  ✓
                %{state | gs: saved_gs, doc: doc3, events: child_result.events ++ state.events}

              {:error, _} ->
                state
            end

          {:error, _} ->
            state
        end

      {:error, _} ->
        state
    end
  end

  # Parse a PDF matrix array [a b c d e f] into a 6-float tuple.
  # Returns nil if array is invalid (caller defaults to identity).
  defp parse_matrix(nil), do: nil

  defp parse_matrix(arr) when is_list(arr) and length(arr) == 6 do
    floats = Enum.map(arr, &numeric_to_float/1)

    if Enum.any?(floats, &is_nil/1) do
      nil
    else
      List.to_tuple(floats)
    end
  end

  defp parse_matrix(_), do: nil

  defp numeric_to_float(n) when is_integer(n), do: n * 1.0
  defp numeric_to_float(n) when is_float(n), do: n
  defp numeric_to_float({:integer, n}), do: n * 1.0
  defp numeric_to_float({:float, n}), do: n
  defp numeric_to_float(_), do: nil

  # ---------------------------------------------------------------------------
  # TJ array processing
  # ---------------------------------------------------------------------------

  defp process_tj_array([], gs, _decoder, events), do: {gs, events}

  defp process_tj_array([item | rest], gs, decoder, events) do
    case item do
      {:integer, n} ->
        new_gs = kern_tm(gs, n)
        process_tj_array(rest, new_gs, decoder, events)

      {:float, n} ->
        new_gs = kern_tm(gs, n)
        process_tj_array(rest, new_gs, decoder, events)

      _ ->
        bytes = token_bytes(item)
        {text, unresolved} = decoder.(bytes)
        {x, y} = absolute_position(gs)

        event =
          {:text,
           %{text: text, unresolved: unresolved, x: x, y: y, font: gs.font, size: gs.font_size}}

        new_gs = advance_tm(gs, bytes)
        process_tj_array(rest, new_gs, decoder, [event | events])
    end
  end

  # ---------------------------------------------------------------------------
  # Position math
  # ---------------------------------------------------------------------------

  # Absolute position = Tm × CTM, then take the translation components (e, f).
  # Spec: PDF 1.7 § 8.3.3, § 9.4.4
  defp absolute_position(%GraphicsState{tm: tm, ctm: ctm}) do
    {_a, _b, _c, _d, e, f} = GraphicsState.multiply(tm, ctm)
    {e, f}
  end

  # Advance Tm after showing text, using the full § 9.4.4 formula:
  #
  #   tx = sum over each glyph byte/pair of:
  #     ((w / 1000.0) * Tfs + Tc + (if byte == 0x20, do: Tw, else: 0)) * Th
  #
  # Where:
  #   w      — per-glyph width in glyph-space units (from gs.widths_fn, or 0 if nil)
  #   Tfs    — font size (gs.font_size)
  #   Tc     — character spacing (gs.char_spacing)
  #   Tw     — word spacing (gs.word_spacing), applied IFF raw glyph bytes == <<0x20>>
  #   Th     — horizontal scaling (gs.horizontal_scaling / 100.0)
  #
  # `bytes` is the raw binary passed to the font (before decoding).
  # Spec reference: PDF 1.7 § 9.4.4
  @doc false
  def advance_tm(gs, bytes) when is_binary(bytes) do
    %{
      tm: {a, b, c, d, e, f},
      font_size: tfs,
      char_spacing: tc,
      word_spacing: tw,
      horizontal_scaling: th_pct,
      widths_fn: widths_fn
    } = gs

    th = th_pct / 100.0

    widths =
      if is_function(widths_fn, 1) do
        widths_fn.(bytes)
      else
        # nil widths_fn → w=0 for every glyph
        glyph_count_for_nil_widths(bytes, widths_fn)
      end

    tx = compute_tx(bytes, widths, tfs, tc, tw, th)

    new_tm = {a, b, c, d, e + tx * a, f + tx * b}
    %{gs | tm: new_tm}
  end

  # Compute total tx from the glyph list.
  # Each glyph contributes its portion. The byte matching for Tw uses the raw bytes
  # consumed per glyph: for simple fonts 1 byte/glyph, for CID 2 bytes/glyph.
  defp compute_tx(bytes, widths, tfs, tc, tw, th) do
    glyph_size = if length(widths) > 0, do: div(byte_size(bytes), length(widths)), else: 1

    {tx_total, _} =
      Enum.reduce(widths, {0.0, 0}, fn w, {acc_tx, offset} ->
        glyph_bytes = binary_part(bytes, offset, min(glyph_size, byte_size(bytes) - offset))
        tx = glyph_advance(w, glyph_bytes, tfs, tc, tw, th)
        {acc_tx + tx, offset + glyph_size}
      end)

    tx_total
  end

  # Compute tx for a single glyph. Pure function; no side effects.
  # Formula: ((w / 1000.0) * Tfs + Tc + Tw_if_space) * Th
  # Tw_if_space: word spacing applied IFF raw glyph bytes are <<0x20>> or <<0x00, 0x20>>.
  # Spec reference: PDF 1.7 § 9.4.4
  defp glyph_advance(w, glyph_bytes, tfs, tc, tw, th) do
    tw_term = if is_space_glyph(glyph_bytes), do: tw, else: 0.0
    (w / 1000.0 * tfs + tc + tw_term) * th
  end

  # Space glyph detection (before decoding).
  # Simple font: single byte 0x20. CID font: two bytes <<0x00, 0x20>>.
  defp is_space_glyph(<<0x20>>), do: true
  defp is_space_glyph(<<0x00, 0x20>>), do: true
  defp is_space_glyph(_), do: false

  # When widths_fn is nil: return list of zeros, one per glyph.
  # Simple heuristic: 1 zero per byte (simple font default).
  defp glyph_count_for_nil_widths(bytes, _nil_fn) do
    List.duplicate(0, byte_size(bytes))
  end

  # Kern Tm by -(n/1000) × Tfs × Th (TJ numeric element).
  # Spec § 9.4.4: Tc and Tw do NOT apply to kerning adjustments.
  defp kern_tm(
         %{tm: {a, b, c, d, e, f}, font_size: size, horizontal_scaling: th_pct} = gs,
         n
       ) do
    th = th_pct / 100.0
    shift = -(n / 1000.0) * size * th
    new_tm = {a, b, c, d, e + shift * a, f + shift * b}
    %{gs | tm: new_tm}
  end

  # Apply Td: Tlm = [1 0 0 1 tx ty] × Tlm; Tm = Tlm
  defp apply_td(%{tlm: tlm} = gs, tx, ty) do
    delta = {1.0, 0.0, 0.0, 1.0, tx, ty}
    new_tlm = GraphicsState.multiply(delta, tlm)
    %{gs | tlm: new_tlm, tm: new_tlm}
  end

  # T* is equivalent to Td(0, -leading)
  defp apply_tstar_gs(%{leading: leading} = gs), do: apply_td(gs, 0.0, -leading)

  # Apply T* to state (for ' operator)
  defp apply_tstar(%{gs: gs} = state) do
    %{state | gs: apply_tstar_gs(gs)}
  end

  # ---------------------------------------------------------------------------
  # Operand stack helpers
  # ---------------------------------------------------------------------------

  # Pop 1 operand from the reversed-list stack (head = most recent push)
  defp pop1([op | rest]), do: {op, rest}
  defp pop1([]), do: {{:integer, 0}, []}

  # Pop 2 operands (first in stream order = second in stack)
  defp pop2([op2, op1 | rest]), do: {op1, op2, rest}
  defp pop2([op1]), do: {op1, {:integer, 0}, []}
  defp pop2([]), do: {{:integer, 0}, {:integer, 0}, []}

  # Pop 6 operands for matrix operators
  defp pop6([f, e, d, c, b, a | rest]), do: {a, b, c, d, e, f, rest}

  defp pop6(ops) do
    vals = Enum.take(ops, 6) |> Enum.reverse()
    padded = vals ++ List.duplicate({:integer, 0}, max(0, 6 - length(vals)))
    [a, b, c, d, e, f] = Enum.take(padded, 6)
    {a, b, c, d, e, f, []}
  end

  # Pop 3 for " operator: [string, ac, aw] in stack order
  defp pop3_with_str([str, ac, aw | rest]), do: {aw, ac, str, rest}

  defp pop3_with_str(ops) do
    case ops do
      [str, ac] -> {{:integer, 0}, ac, str, []}
      [str] -> {{:integer, 0}, {:integer, 0}, str, []}
      [] -> {{:integer, 0}, {:integer, 0}, {:string, ""}, []}
    end
  end

  # Pop the array from the operand stack.
  # After handle_array, the stack has [:array_open, item, item, ... ] (reversed).
  # Most recent push is head, so items from [ to :array_open are collected.
  defp pop_array(operands) do
    {array_items, rest} = collect_array_items(operands, [])
    {array_items, rest}
  end

  defp collect_array_items([], acc), do: {acc, []}

  defp collect_array_items([:array_open | rest], acc) do
    {acc, rest}
  end

  defp collect_array_items([item | rest], acc) do
    collect_array_items(rest, [item | acc])
  end

  # ---------------------------------------------------------------------------
  # Type coercions
  # ---------------------------------------------------------------------------

  defp to_float({:integer, n}), do: n * 1.0
  defp to_float({:float, f}), do: f
  defp to_float(_), do: 0.0

  defp to_name({:name, n}), do: n
  defp to_name(_), do: nil

  defp token_bytes({:string, b}), do: b
  defp token_bytes({:hex_string, b}), do: b
  defp token_bytes(_), do: ""
end
