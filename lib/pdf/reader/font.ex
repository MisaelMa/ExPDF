defmodule Pdf.Reader.Font do
  @moduledoc """
  Per-font decoder construction for the encoding cascade.

  A "decoder" is a closure `(binary -> {String.t(), [{non_neg_integer(), binary()}]})`
  that maps raw font-code bytes to UTF-8 text plus a list of unresolved sentinels.

  ## Simple fonts (Type1, TrueType, etc.)

  Cascade per byte (delegates to `Pdf.Reader.Encoding.resolve_byte/3`):
  ToUnicode CMap → /Differences + AGL → base encoding → U+FFFD + sentinel.

  ## Composite fonts (Type0/Identity-H/V)

  When `/Encoding` is `Identity-H` or `Identity-V`, the font is dispatched to
  `Pdf.Reader.CID.Decoder.build/2`. The CID decoder consumes bytes in 2-byte
  big-endian chunks and resolves via:
  ToUnicode CMap → Adobe registry table (Japan1/CNS1/Korea1/GB1) → U+FFFD.

  Non-Identity predefined CMaps (`UniJIS-UTF16-H`, `GBK-EUC-H`, etc.) are
  also supported when bundled in `priv/cmap/` — the decoder dispatches to
  `Pdf.Reader.CID.Decoder.build_predefined/2` which uses
  `Pdf.Reader.CID.PredefinedCMap` for byte→CID lookup followed by the
  same Adobe registry → Unicode resolution as Identity-H/V.

  ## Cache

  Decoders for fonts referenced by indirect ref `{:ref, n, g}` are cached in
  `Document.cache` under key `{:font_decoder, {n, g}}` for reuse across pages
  with shared font resources. Inline font dicts (plain maps, no ref) are NOT
  cached.

  ## Recovery mode (R-2)

  When `doc.recover_mode` is `true` and a font dict fails to resolve or build,
  `build_decoders_for_resources/2` installs a fallback U+FFFD identity decoder
  for that font instead of returning `{:error, _}`. The fallback emits
  `<<0xFFFD::utf8>>` per input byte, which guarantees `String.valid?/1` is
  `true` on the resulting text. A `{:font_skipped, page_n, font_name, reason}`
  event is logged to `doc.recovery_log` for each failed font. Fonts that build
  successfully are NOT affected.

  Spec: PDF 1.7 § 9.6 (font dictionaries), § 9.10 (text content extraction).

  ## Spec references
  - PDF 1.7 § 9.6 — Type 1 Fonts:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.6.5, § 9.6.5.1 — Character Encoding, /Differences arrays
  - PDF 1.7 § 9.7 — Composite Fonts (Type0, CIDFonts, CMaps)
  - PDF 1.7 § 9.7.4 — CIDFonts
  - PDF 1.7 § 9.7.5 — Predefined CMaps (Identity-H, Identity-V)
  - PDF 1.7 § 9.10.3 — ToUnicode CMaps
  """

  alias Pdf.Reader.CID
  alias Pdf.Reader.CID.PredefinedCMap
  alias Pdf.Reader.{CMap, Document, Encoding, Filter, ObjectResolver}
  alias Pdf.Reader.Encoding.Differences

  @type decoder_fn :: (binary() -> {String.t(), [{non_neg_integer(), binary()}]})

  @doc """
  Build a decoder closure for a font.

  Accepts either:
  - A `font_dict` (plain map) — inline font, built directly without caching.
  - A `{:ref, n, g}` tuple — indirect font reference; result is cached in
    `doc.cache` under `{:font_decoder, {n, g}}`.

  Returns `{:ok, decoder_fn, updated_doc}`.
  """
  @spec build_decoder(map() | {:ref, pos_integer(), non_neg_integer()}, Document.t()) ::
          {:ok, decoder_fn(), Document.t()} | {:error, term()}
  def build_decoder({:ref, n, g} = font_ref, doc) do
    cache_key = {:font_decoder, {n, g}}

    case Map.get(doc.cache, cache_key) do
      nil ->
        # Cache miss: resolve the font dict, build the decoder, store it.
        with {:ok, font_dict, doc2} <- ObjectResolver.resolve(doc, font_ref) do
          {decoder, doc3} = build_decoder_internal(font_dict, doc2)
          cached_doc = %{doc3 | cache: Map.put(doc3.cache, cache_key, decoder)}
          {:ok, decoder, cached_doc}
        end

      cached_decoder ->
        {:ok, cached_decoder, doc}
    end
  end

  def build_decoder(font_dict, doc) when is_map(font_dict) do
    {decoder, doc2} = build_decoder_internal(font_dict, doc)
    {:ok, decoder, doc2}
  end

  @doc """
  Build decoders for all fonts in a page's resources map.

  Walks `resources["Font"]` (a map of font name → font dict or ref) and calls
  `build_decoder/2` for each entry. Returns a map keyed by font name.

  In strict mode (`doc.recover_mode == false`): returns `{:ok, decoders, [], doc}`
  on success, or `{:error, reason}` on first font build failure (unchanged).

  In recovery mode (`doc.recover_mode == true`): on per-font build failure,
  installs a per-byte U+FFFD fallback decoder for that font name and appends
  `{font_name, reason}` to the returned `font_failures` list. The page is NOT
  aborted. The caller is responsible for converting failures to
  `{:font_skipped, page_n, font_name, reason}` events and logging them.

  Returns `{:ok, %{font_name => decoder_fn}, [{font_name, reason}], updated_doc}`.

  ## Spec references
  - PDF 1.7 § 9.6 — Font dictionaries
  - PDF 1.7 § 9.10 — Extraction of text content
  """
  @spec build_decoders_for_resources(map(), Document.t()) ::
          {:ok, %{binary() => decoder_fn()}, [{binary(), term()}], Document.t()}
          | {:error, term()}
  def build_decoders_for_resources(resources, doc) do
    font_map = Map.get(resources, "Font", %{}) |> normalize_font_map()

    if doc.recover_mode do
      # R-2: lenient path — per-font try/rescue; install fallback decoder on failure.
      Enum.reduce(font_map, {:ok, %{}, [], doc}, fn {name, font_ref_or_dict},
                                                    {:ok, acc_decoders, acc_failures,
                                                     acc_doc} ->
        case build_decoder(font_ref_or_dict, acc_doc) do
          {:ok, decoder, doc2} ->
            {:ok, Map.put(acc_decoders, name, decoder), acc_failures, doc2}

          {:error, reason} ->
            # Install per-byte U+FFFD fallback decoder (String.valid?/1 guaranteed true).
            fallback = fn bytes -> {String.duplicate("�", byte_size(bytes)), []} end
            {:ok, Map.put(acc_decoders, name, fallback), [{name, reason} | acc_failures], acc_doc}
        end
      end)
    else
      # Strict path — halt on first font build failure (unchanged behavior).
      result =
        Enum.reduce_while(font_map, {:ok, %{}, doc}, fn {name, font_ref_or_dict},
                                                        {:ok, acc, acc_doc} ->
          case build_decoder(font_ref_or_dict, acc_doc) do
            {:ok, decoder, doc2} ->
              {:cont, {:ok, Map.put(acc, name, decoder), doc2}}

            {:error, _reason} = err ->
              {:halt, err}
          end
        end)

      case result do
        {:ok, decoders, doc2} -> {:ok, decoders, [], doc2}
        {:error, _} = err -> err
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  # Resolve the Font resource if it is itself an indirect ref (pointing to a dict).
  defp normalize_font_map(font_map_or_ref) when is_map(font_map_or_ref), do: font_map_or_ref
  defp normalize_font_map(_), do: %{}

  # Core decoder construction from a resolved font dict.
  @spec build_decoder_internal(map(), Document.t()) :: {decoder_fn(), Document.t()}
  defp build_decoder_internal(font_dict, doc) do
    case cid_font_type(font_dict) do
      :identity ->
        # Identity-H/V path: fixed 2-byte CID loop (existing path — R-CID1, R-CID2).
        {:ok, decoder, doc2} = CID.Decoder.build(font_dict, doc)
        {decoder, doc2}

      {:predefined, _name} ->
        # Predefined CMap path: variable-length tokenization via codespace (R-PCM1).
        case CID.Decoder.build_predefined(font_dict, doc) do
          {:ok, decoder, doc2} ->
            {decoder, doc2}

          {:error, {:not_bundled, _}} ->
            # Should not happen since cid_font_type/1 already checked bundled?,
            # but handle gracefully.
            build_simple_decoder(font_dict, doc)

          {:error, _} ->
            build_simple_decoder(font_dict, doc)
        end

      :not_cid ->
        build_simple_decoder(font_dict, doc)
    end
  end

  # Detect the CID font type:
  # - :identity — Type0 with Identity-H or Identity-V
  # - {:predefined, name} — Type0 with a bundled predefined CMap name (R-PCM15, D2)
  # - :not_cid — anything else
  defp cid_font_type(font_dict) do
    case Map.get(font_dict, "Encoding") do
      {:name, "Identity-H"} ->
        :identity

      {:name, "Identity-V"} ->
        :identity

      {:name, name} when is_binary(name) ->
        if PredefinedCMap.bundled?(name), do: {:predefined, name}, else: :not_cid

      _ ->
        :not_cid
    end
  end

  # Simple (1-byte) font decoder — existing path, unchanged.
  defp build_simple_decoder(font_dict, doc) do
    # Step 1: Resolve ToUnicode CMap (if any).
    {cmap, doc2} = resolve_cmap(font_dict, doc)

    # Step 2: Resolve /Encoding → base atom + differences map.
    {base_encoding, differences} = resolve_encoding(font_dict)

    # Step 3: Build closure that applies the cascade for each byte.
    decoder = build_closure(cmap, base_encoding, differences)

    {decoder, doc2}
  end

  # ---------------------------------------------------------------------------
  # CMap resolution
  # ---------------------------------------------------------------------------

  # Test shortcut: pre-parsed CMap stored under "__test_cmap__" key.
  defp resolve_cmap(%{"__test_cmap__" => %CMap{} = cmap}, doc), do: {cmap, doc}

  defp resolve_cmap(font_dict, doc) do
    case Map.get(font_dict, "ToUnicode") do
      nil ->
        {nil, doc}

      {:ref, _, _} = ref ->
        resolve_cmap_ref(ref, doc)

      # Already decoded binary (unlikely from parser, but handle gracefully)
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

  # ---------------------------------------------------------------------------
  # Encoding resolution
  # ---------------------------------------------------------------------------

  # No /Encoding key → nil base, nil differences
  defp resolve_encoding(%{"Encoding" => encoding}) do
    resolve_encoding_value(encoding)
  end

  defp resolve_encoding(_), do: {nil, nil}

  # {:name, "WinAnsiEncoding"} → :win_ansi base, no differences
  defp resolve_encoding_value({:name, name}) when is_binary(name) do
    {name_to_base_atom(name), nil}
  end

  # Encoding dict (inline map) with optional BaseEncoding + Differences
  defp resolve_encoding_value(enc_dict) when is_map(enc_dict) do
    base_name =
      case Map.get(enc_dict, "BaseEncoding") do
        {:name, n} when is_binary(n) -> n
        n when is_binary(n) -> n
        _ -> nil
      end

    base_atom = if base_name, do: name_to_base_atom(base_name), else: nil

    differences =
      case Map.get(enc_dict, "Differences") do
        nil -> nil
        diffs when is_list(diffs) -> Differences.apply(%{}, diffs)
      end

    {base_atom, differences}
  end

  defp resolve_encoding_value(_), do: {nil, nil}

  defp name_to_base_atom("WinAnsiEncoding"), do: :win_ansi
  defp name_to_base_atom("MacRomanEncoding"), do: :mac_roman
  defp name_to_base_atom("StandardEncoding"), do: :standard
  defp name_to_base_atom(_), do: nil

  # ---------------------------------------------------------------------------
  # Closure builder
  # ---------------------------------------------------------------------------

  @unresolved_char "�"

  defp build_closure(cmap, base_encoding, differences) do
    fn bytes ->
      decode_bytes(bytes, cmap, base_encoding, differences)
    end
  end

  defp decode_bytes(bytes, cmap, base_encoding, differences) do
    {text_iodata, unresolved, _idx} =
      for <<byte <- bytes>>, reduce: {[], [], 0} do
        {text_acc, unresolved_acc, idx} ->
          case Encoding.resolve_byte(byte, cmap,
                 differences: differences,
                 base_encoding: base_encoding
               ) do
            {:ok, codepoint} ->
              {[text_acc, <<codepoint::utf8>>], unresolved_acc, idx + 1}

            {:unresolved, marker} ->
              {[text_acc, @unresolved_char], [{idx, marker} | unresolved_acc], idx + 1}
          end
      end

    text = IO.iodata_to_binary(text_iodata)
    unresolved_list = Enum.reverse(unresolved)
    {text, unresolved_list}
  end
end
