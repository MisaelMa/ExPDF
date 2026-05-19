defmodule Pdf.Reader.CID.Decoder do
  @moduledoc """
  CID font decoder for Type0/Identity-H and Identity-V composite fonts.

  Returns a `decoder_fn()` closure with the same contract as the simple-font
  decoder: `(binary() -> {String.t(), [{non_neg_integer(), binary()}]})`.

  ## Resolution cascade (per CID)

  1. **ToUnicode CMap** — if the font has a `/ToUnicode` stream, its `bf_char`/
     `bf_range` entries are checked first (most specific).
  2. **Adobe registry table** — `/CIDSystemInfo /Ordering` maps to one of the four
     bundled collection modules (`AdobeJapan1`, `AdobeCNS1`, `AdobeKorea1`,
     `AdobeGB1`). O(1) pattern-match dispatch.
  3. **U+FFFD fallback** — unresolved CIDs yield `U+FFFD` plus a sentinel tuple
     `{idx, "cid:0xHHHH"}` appended to the unresolved list.

  ## `__test_cmap__` shortcut

  For unit tests, a pre-parsed `%Pdf.Reader.CMap{}` can be injected by storing
  it in the font dict under the key `"__test_cmap__"`. This bypasses stream
  resolution. (Mirrors the same shortcut in `Pdf.Reader.Font`.)

  ## Width / advance computation

  This module handles **character decoding only** (bytes → Unicode text). Glyph
  advance widths (`/W` and `/DW` entries on the DescendantFonts[0] dict) are read
  separately by `Pdf.Reader.Font.Widths` (§ 9.7.4.3). The two concerns are
  intentionally kept in separate modules: decoding and advance computation are
  independent of each other.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.7.4 — CIDFonts
  - PDF 1.7 § 9.7.4.3 — /W and /DW arrays (handled by `Pdf.Reader.Font.Widths`)
  - PDF 1.7 § 9.7.5 — CMaps (Identity-H, Identity-V predefined)
  """

  alias Pdf.Reader.CID.{
    AdobeCNS1,
    AdobeGB1,
    AdobeJapan1,
    AdobeKorea1,
    CIDToGIDMap,
    Codespace,
    PredefinedCMap
  }

  alias Pdf.Reader.{CMap, Document, Filter, ObjectResolver}

  @type decoder_fn :: (binary() -> {String.t(), [{non_neg_integer(), binary()}]})

  @unresolved_char "�"

  @doc """
  Build a CID decoder closure from a Type0 font dict.

  `font_dict` is the top-level Type0 font dictionary (already resolved).
  Reads `DescendantFonts`, `CIDSystemInfo`, `CIDToGIDMap`, and `ToUnicode`.

  Returns `{:ok, decoder_fn, updated_doc}`.
  """
  @spec build(map(), Document.t()) :: {:ok, decoder_fn(), Document.t()} | {:error, term()}
  def build(font_dict, doc) do
    # Step 1: Resolve ToUnicode CMap (may be nil).
    {cmap, doc1} = resolve_cmap(font_dict, doc)

    # Step 2: Resolve DescendantFonts array → first descendant CIDFont dict.
    {descendant, doc2} = resolve_descendant(font_dict, doc1)

    # Step 3: Extract registry atom from CIDSystemInfo.Ordering.
    registry_atom = parse_registry(descendant)

    # Step 4: Parse CIDToGIDMap (stored for completeness; not used in Unicode cascade).
    {_cid_to_gid, doc3} =
      case Map.get(descendant, "CIDToGIDMap") do
        nil ->
          {:identity, doc2}

        cid_to_gid_value ->
          case CIDToGIDMap.parse(cid_to_gid_value, doc2) do
            {:ok, map, doc_out} -> {map, doc_out}
            {:error, _} -> {:identity, doc2}
          end
      end

    # Step 5: Build and return the closure.
    decoder = build_closure(cmap, registry_atom)
    {:ok, decoder, doc3}
  end

  @doc """
  Build a predefined CMap decoder closure from a Type0 font dict whose
  `/Encoding` names a bundled predefined CMap (e.g. `UniJIS-UTF16-H`).

  Resolution cascade per code token (PDF 1.7 § 9.7.5, D9):
  1. **ToUnicode CMap** — if present, checked first (most specific).
  2. **Predefined CMap** — `cidchar` → `cidrange` → `notdef` lookup.
  3. **Adobe registry table** — CID → Unicode via AdobeJapan1/CNS1/Korea1/GB1.
  4. **U+FFFD fallback** — unresolved codes yield `U+FFFD` + sentinel.

  Returns `{:ok, decoder_fn, updated_doc}`.
  """
  @spec build_predefined(map(), Document.t()) ::
          {:ok, decoder_fn(), Document.t()} | {:error, term()}
  def build_predefined(font_dict, doc) do
    # Step 1: Resolve ToUnicode CMap (may be nil).
    {to_unicode, doc1} = resolve_cmap(font_dict, doc)

    # Step 2: Extract predefined CMap name and load it.
    predefined_name =
      case Map.get(font_dict, "Encoding") do
        {:name, name} -> name
        _ -> nil
      end

    with {:ok, predefined, doc2} <- PredefinedCMap.load_by_name(predefined_name, doc1) do
      # Step 3: Resolve DescendantFonts → CIDSystemInfo registry atom.
      {descendant, doc3} = resolve_descendant(font_dict, doc2)
      registry_atom = parse_registry(descendant)

      # Step 4: Build the predefined closure.
      decoder = build_predefined_closure(predefined, registry_atom, to_unicode)
      {:ok, decoder, doc3}
    end
  end

  # ---------------------------------------------------------------------------
  # Predefined CMap closure builder
  # ---------------------------------------------------------------------------

  defp build_predefined_closure(predefined, registry_atom, to_unicode) do
    fn bytes ->
      codes = Codespace.tokenize(bytes, predefined.codespaces)
      decode_predefined_codes(codes, predefined, registry_atom, to_unicode, [], [], 0)
    end
  end

  defp decode_predefined_codes([], _pred, _reg, _tou, text_acc, unresolved_acc, _idx) do
    {IO.iodata_to_binary(Enum.reverse(text_acc)), Enum.reverse(unresolved_acc)}
  end

  defp decode_predefined_codes([code | rest], pred, reg, tou, text_acc, unresolved_acc, idx) do
    # 1. ToUnicode CMap takes precedence (R-PCM17, D9)
    case to_unicode_lookup(tou, code) do
      {:ok, string} ->
        decode_predefined_codes(
          rest,
          pred,
          reg,
          tou,
          [string | text_acc],
          unresolved_acc,
          idx + 1
        )

      :error ->
        # 2. Predefined CMap lookup → CID
        case PredefinedCMap.lookup(pred, code) do
          {:ok, cid} ->
            # 3. Registry lookup → Unicode codepoint
            case registry_lookup(cid, reg) do
              {:ok, codepoint} ->
                decode_predefined_codes(
                  rest,
                  pred,
                  reg,
                  tou,
                  [<<codepoint::utf8>> | text_acc],
                  unresolved_acc,
                  idx + 1
                )

              :error ->
                hex = String.pad_leading(Integer.to_string(cid, 16), 4, "0")
                sentinel = {idx, "cid:0x" <> hex}

                decode_predefined_codes(
                  rest,
                  pred,
                  reg,
                  tou,
                  [@unresolved_char | text_acc],
                  [sentinel | unresolved_acc],
                  idx + 1
                )
            end

          :error ->
            # 4. Code in codespace but unmapped → U+FFFD + sentinel
            hex = String.pad_leading(Integer.to_string(code, 16), 4, "0")
            sentinel = {idx, "code:0x" <> hex}

            decode_predefined_codes(
              rest,
              pred,
              reg,
              tou,
              [@unresolved_char | text_acc],
              [sentinel | unresolved_acc],
              idx + 1
            )
        end
    end
  end

  # ToUnicode lookup helper — returns {:ok, string} or :error
  defp to_unicode_lookup(nil, _code), do: :error

  defp to_unicode_lookup(%CMap{} = cmap, code) do
    case CMap.lookup(cmap, code) do
      nil -> :error
      string when is_binary(string) -> {:ok, string}
    end
  end

  # ---------------------------------------------------------------------------
  # Closure builder (Identity-H/V path)
  # ---------------------------------------------------------------------------

  defp build_closure(cmap, registry_atom) do
    fn bytes ->
      {text_chunks, unresolved, _idx} =
        for <<cid::big-unsigned-16 <- bytes>>, reduce: {[], [], 0} do
          {text_acc, unresolved_acc, idx} ->
            case resolve_cid(cid, cmap, registry_atom) do
              {:ok, codepoint} ->
                {[text_acc, <<codepoint::utf8>>], unresolved_acc, idx + 1}

              :error ->
                sentinel =
                  {idx, "cid:0x" <> String.pad_leading(Integer.to_string(cid, 16), 4, "0")}

                {[text_acc, @unresolved_char], [sentinel | unresolved_acc], idx + 1}
            end
        end

      {IO.iodata_to_binary(text_chunks), Enum.reverse(unresolved)}
    end
  end

  # ---------------------------------------------------------------------------
  # CID resolution cascade
  # ---------------------------------------------------------------------------

  defp resolve_cid(cid, cmap, registry_atom) do
    cmap_result =
      case cmap do
        nil -> nil
        _ -> CMap.lookup(cmap, cid)
      end

    case cmap_result do
      nil ->
        registry_lookup(cid, registry_atom)

      string when is_binary(string) ->
        # CMap returns a UTF-8 string; extract the first codepoint.
        case String.to_charlist(string) do
          [cp | _] -> {:ok, cp}
          [] -> :error
        end
    end
  end

  defp registry_lookup(cid, :japan1), do: AdobeJapan1.lookup(cid)
  defp registry_lookup(cid, :cns1), do: AdobeCNS1.lookup(cid)
  defp registry_lookup(cid, :korea1), do: AdobeKorea1.lookup(cid)
  defp registry_lookup(cid, :gb1), do: AdobeGB1.lookup(cid)
  defp registry_lookup(_cid, _), do: :error

  # ---------------------------------------------------------------------------
  # Registry atom parsing
  # ---------------------------------------------------------------------------

  defp parse_registry(descendant) when is_map(descendant) do
    case Map.get(descendant, "CIDSystemInfo") do
      %{"Ordering" => ordering} -> ordering_to_atom(ordering)
      _ -> nil
    end
  end

  # PDF strings come from the parser as {:string, value} or plain binary strings
  # depending on how they appear in the PDF (literal string vs name).
  defp ordering_to_atom({:string, ordering}), do: ordering_to_atom(ordering)
  defp ordering_to_atom("Japan1"), do: :japan1
  defp ordering_to_atom("CNS1"), do: :cns1
  defp ordering_to_atom("Korea1"), do: :korea1
  defp ordering_to_atom("GB1"), do: :gb1
  defp ordering_to_atom(_), do: nil

  # ---------------------------------------------------------------------------
  # DescendantFonts resolution
  # ---------------------------------------------------------------------------

  defp resolve_descendant(font_dict, doc) do
    case Map.get(font_dict, "DescendantFonts") do
      [first | _] ->
        resolve_font_value(first, doc)

      _ ->
        {%{}, doc}
    end
  end

  defp resolve_font_value({:ref, _, _} = ref, doc) do
    case ObjectResolver.resolve(doc, ref) do
      {:ok, dict, doc2} when is_map(dict) -> {dict, doc2}
      _ -> {%{}, doc}
    end
  end

  defp resolve_font_value(dict, doc) when is_map(dict), do: {dict, doc}
  defp resolve_font_value(_, doc), do: {%{}, doc}

  # ---------------------------------------------------------------------------
  # CMap resolution (mirrors Font.resolve_cmap pattern)
  # ---------------------------------------------------------------------------

  # Test shortcut: pre-parsed CMap stored under "__test_cmap__" key.
  defp resolve_cmap(%{"__test_cmap__" => %CMap{} = cmap}, doc), do: {cmap, doc}

  defp resolve_cmap(font_dict, doc) do
    case Map.get(font_dict, "ToUnicode") do
      nil ->
        {nil, doc}

      {:ref, _, _} = ref ->
        resolve_cmap_ref(ref, doc)

      binary when is_binary(binary) ->
        {CMap.parse(binary), doc}
    end
  end

  defp resolve_cmap_ref(ref, doc) do
    with {:ok, {:stream, dict, raw_bytes}, doc2} <- ObjectResolver.resolve(doc, ref),
         filter = Map.get(dict, "Filter"),
         parms = Map.get(dict, "DecodeParms"),
         {:ok, decoded} <- decode_stream(raw_bytes, filter, parms) do
      {CMap.parse(decoded), doc2}
    else
      _ -> {nil, doc}
    end
  end

  defp decode_stream(raw_bytes, nil, _parms), do: {:ok, raw_bytes}

  defp decode_stream(raw_bytes, filter, parms) do
    Filter.apply_chain(raw_bytes, filter, parms || %{})
  end
end
