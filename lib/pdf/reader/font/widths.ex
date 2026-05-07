defmodule Pdf.Reader.Font.Widths do
  @moduledoc """
  Per-font glyph-width lookup for text advance computation.

  Builds closures of type `(binary() -> [non_neg_integer()])` that return, for
  a binary of raw font bytes, a list of glyph-space advance widths (one per
  glyph code encoded in the binary).

  ## Simple fonts (Type1, TrueType)

  Width lookup uses `/Widths`, `/FirstChar`, `/LastChar` from the font dict.
  Out-of-range codes fall back to `/MissingWidth` from `/FontDescriptor`, or
  `0` if absent. (§ 9.6.2.1, § 9.6.4)

  ## CIDFonts (Type0 → DescendantFonts[0])

  Width lookup uses `/W` (Form A and Form B entries) and `/DW` (default: 1000).
  (§ 9.7.4.3)

  ## Cache

  Widths closures for fonts referenced via `{:ref, n, g}` are cached in
  `Document.cache` under key `{:font_widths, {n, g}}`, mirroring the decoder
  cache strategy of `Pdf.Reader.Font`.

  ## Spec references

  - PDF 1.7 § 9.4.4  — Text advance formula (tx per glyph)
  - PDF 1.7 § 9.6.2.1 — Simple font /Widths, /FirstChar, /LastChar
  - PDF 1.7 § 9.6.4   — Font descriptor /MissingWidth
  - PDF 1.7 § 9.7.4.3 — CIDFont /W and /DW arrays
  """

  alias Pdf.Reader.{Document, ObjectResolver}

  @type widths_fn :: (binary() -> [non_neg_integer()])

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Build a widths closure for a font dict or indirect reference.

  Returns `{:ok, widths_fn, updated_doc}`.

  Spec: § 9.6.2.1 (simple fonts), § 9.7.4.3 (CIDFonts).
  """
  @spec build_widths_fn(map() | {:ref, pos_integer(), non_neg_integer()}, Document.t()) ::
          {:ok, widths_fn(), Document.t()} | {:error, term()}
  def build_widths_fn({:ref, n, g} = font_ref, doc) do
    cache_key = {:font_widths, {n, g}}

    case Map.get(doc.cache, cache_key) do
      nil ->
        with {:ok, font_dict, doc2} <- ObjectResolver.resolve(doc, font_ref) do
          {widths_fn, doc3} = build_widths_internal(font_dict, doc2)
          cached_doc = %{doc3 | cache: Map.put(doc3.cache, cache_key, widths_fn)}
          {:ok, widths_fn, cached_doc}
        end

      cached_fn ->
        {:ok, cached_fn, doc}
    end
  end

  def build_widths_fn(font_dict, doc) when is_map(font_dict) do
    # Test shortcut: if "__test_widths__" key is present, use it directly
    case Map.get(font_dict, "__test_widths__") do
      nil ->
        {widths_fn, doc2} = build_widths_internal(font_dict, doc)
        {:ok, widths_fn, doc2}

      fn_or_map when is_function(fn_or_map, 1) ->
        {:ok, fn_or_map, doc}
    end
  end

  @doc """
  Build widths closures for all fonts in a page's resources map.

  Mirrors `Pdf.Reader.Font.build_decoders_for_resources/2`.
  Returns `{:ok, %{font_name => widths_fn}, updated_doc}`.

  When `doc.recover_mode` is `true`: on per-font widths failure, installs a
  zero-width fallback (all glyphs advance 0) and continues. The font_skipped
  event is already logged by `build_decoders_for_resources`; no duplicate event
  is emitted here.

  When `doc.recover_mode` is `false`: halts on first font widths failure
  (unchanged strict behavior).
  """
  @spec build_widths_for_resources(map(), Document.t()) ::
          {:ok, %{binary() => widths_fn()}, Document.t()} | {:error, term()}
  def build_widths_for_resources(resources, doc) do
    font_map = Map.get(resources, "Font", %{}) |> normalize_font_map()

    if doc.recover_mode do
      # R-2: lenient path — install zero-width fallback on failure; never halt.
      result =
        Enum.reduce(font_map, {:ok, %{}, doc}, fn {name, font_ref_or_dict},
                                                  {:ok, acc, acc_doc} ->
          case build_widths_fn(font_ref_or_dict, acc_doc) do
            {:ok, widths_fn, doc2} ->
              {:ok, Map.put(acc, name, widths_fn), doc2}

            {:error, _reason} ->
              # Zero-width fallback: all bytes advance 0 (no horizontal movement).
              fallback_widths = fn bytes -> List.duplicate(0, byte_size(bytes)) end
              {:ok, Map.put(acc, name, fallback_widths), acc_doc}
          end
        end)

      result
    else
      Enum.reduce_while(font_map, {:ok, %{}, doc}, fn {name, font_ref_or_dict},
                                                      {:ok, acc, acc_doc} ->
        case build_widths_fn(font_ref_or_dict, acc_doc) do
          {:ok, widths_fn, doc2} ->
            {:cont, {:ok, Map.put(acc, name, widths_fn), doc2}}

          {:error, _reason} = err ->
            {:halt, err}
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp normalize_font_map(font_map) when is_map(font_map), do: font_map
  defp normalize_font_map(_), do: %{}

  # Dispatch to simple or CID path based on font subtype
  @spec build_widths_internal(map(), Document.t()) :: {widths_fn(), Document.t()}
  defp build_widths_internal(font_dict, doc) do
    case is_cid_font?(font_dict) do
      true -> parse_cid(font_dict, doc)
      false -> parse_simple(font_dict, doc)
    end
  end

  defp is_cid_font?(font_dict) do
    case Map.get(font_dict, "Subtype") do
      {:name, "Type0"} -> true
      _ -> false
    end
  end

  # ---------------------------------------------------------------------------
  # parse_simple/2 — simple fonts (Type1, TrueType, etc.)
  # Spec: § 9.6.2.1, § 9.6.4
  # ---------------------------------------------------------------------------

  @doc false
  @spec parse_simple(map(), Document.t()) :: {widths_fn(), Document.t()}
  def parse_simple(font_dict, doc) do
    first_char = int_val(Map.get(font_dict, "FirstChar"), 0)
    last_char = int_val(Map.get(font_dict, "LastChar"), -1)
    widths_list = list_val(Map.get(font_dict, "Widths"), [])

    {missing_width, doc2} = resolve_missing_width(font_dict, doc)

    widths_fn = fn bytes ->
      for <<byte <- bytes>> do
        if byte >= first_char and byte <= last_char do
          idx = byte - first_char

          case Enum.at(widths_list, idx) do
            nil -> missing_width
            w -> int_val(w, missing_width)
          end
        else
          missing_width
        end
      end
    end

    {widths_fn, doc2}
  end

  # Resolve /MissingWidth from /FontDescriptor (may be an indirect ref).
  defp resolve_missing_width(font_dict, doc) do
    case Map.get(font_dict, "FontDescriptor") do
      nil ->
        {0, doc}

      {:ref, _, _} = ref ->
        case ObjectResolver.resolve(doc, ref) do
          {:ok, descriptor, doc2} when is_map(descriptor) ->
            mw = int_val(Map.get(descriptor, "MissingWidth"), 0)
            {mw, doc2}

          _ ->
            {0, doc}
        end

      descriptor when is_map(descriptor) ->
        mw = int_val(Map.get(descriptor, "MissingWidth"), 0)
        {mw, doc}

      _ ->
        {0, doc}
    end
  end

  # ---------------------------------------------------------------------------
  # parse_cid/2 — CIDFonts (Type0 with DescendantFonts)
  # Spec: § 9.7.4.3
  # ---------------------------------------------------------------------------

  @doc false
  @spec parse_cid(map(), Document.t()) :: {widths_fn(), Document.t()}
  def parse_cid(font_dict, doc) do
    {cid_dict, doc2} = resolve_descendant(font_dict, doc)

    dw = int_val(Map.get(cid_dict, "DW"), 1000)
    w_array = list_val(Map.get(cid_dict, "W"), [])
    width_map = parse_w_array(w_array)

    widths_fn = fn bytes ->
      cid_widths_for_bytes(bytes, width_map, dw)
    end

    {widths_fn, doc2}
  end

  # Decode 2-byte big-endian CIDs from bytes and return their widths.
  defp cid_widths_for_bytes(bytes, width_map, dw) do
    byte_count = byte_size(bytes)
    pair_count = div(byte_count, 2)

    for i <- 0..(pair_count - 1), pair_count > 0 do
      <<_::binary-size(i * 2), high, low, _::binary>> = bytes
      cid = high * 256 + low
      Map.get(width_map, cid, dw)
    end
  end

  defp resolve_descendant(font_dict, doc) do
    case Map.get(font_dict, "DescendantFonts") do
      [first | _] when is_map(first) ->
        {first, doc}

      [{:ref, _, _} = ref | _] ->
        case ObjectResolver.resolve(doc, ref) do
          {:ok, dict, doc2} when is_map(dict) -> {dict, doc2}
          _ -> {%{}, doc}
        end

      _ ->
        {%{}, doc}
    end
  end

  # ---------------------------------------------------------------------------
  # parse_w_array/1 — hand-rolled state machine for /W array
  # Handles Form A (c [w1 w2 …]) and Form B (c1 c2 w) interleaved.
  # Spec: § 9.7.4.3
  # ---------------------------------------------------------------------------

  @doc """
  Parse a CIDFont `/W` array into a `%{cid => width}` map.

  Supports:
  - Form A: `c [w1 w2 …]` — CID `c`, `c+1`, … each get successive widths
  - Form B: `c1 c2 w` — all CIDs from `c1` to `c2` inclusive get width `w`

  Both forms may be interleaved in the same array. (§ 9.7.4.3)
  """
  @spec parse_w_array([term()]) :: %{non_neg_integer() => non_neg_integer()}
  def parse_w_array(w_array) do
    do_parse_w(w_array, %{})
  end

  # State machine: no tokens left
  defp do_parse_w([], acc), do: acc

  # Form A: current token is an integer, next is a list → expand list from start_cid
  defp do_parse_w([c, widths_list | rest], acc) when is_integer(c) and is_list(widths_list) do
    new_acc = expand_form_a(c, widths_list, acc)
    do_parse_w(rest, new_acc)
  end

  # Form B: three consecutive integers → range
  defp do_parse_w([c1, c2, w | rest], acc)
       when is_integer(c1) and is_integer(c2) and is_integer(w) do
    new_acc = expand_form_b(c1, c2, w, acc)
    do_parse_w(rest, new_acc)
  end

  # Malformed / trailing integer with no valid continuation → skip
  defp do_parse_w([_c | rest], acc), do: do_parse_w(rest, acc)

  defp expand_form_a(_cid, [], acc), do: acc

  defp expand_form_a(cid, [w | rest_widths], acc) do
    expand_form_a(cid + 1, rest_widths, Map.put(acc, cid, int_val(w, 0)))
  end

  defp expand_form_b(c1, c2, w, acc) when c1 > c2, do: Map.put(acc, c1, int_val(w, 0))

  defp expand_form_b(c1, c2, w, acc) do
    Enum.reduce(c1..c2, acc, fn cid, a -> Map.put(a, cid, int_val(w, 0)) end)
  end

  # ---------------------------------------------------------------------------
  # Value coercions
  # ---------------------------------------------------------------------------

  defp int_val(n, _default) when is_integer(n), do: n
  defp int_val(n, _default) when is_float(n), do: trunc(n)
  defp int_val({:integer, n}, _default), do: n
  defp int_val({:float, n}, _default), do: trunc(n)
  defp int_val(nil, default), do: default
  defp int_val(_, default), do: default

  defp list_val(l, _default) when is_list(l), do: l
  defp list_val(_, default), do: default
end
