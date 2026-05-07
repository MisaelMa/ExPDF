defmodule Pdf.Reader.Font do
  @moduledoc """
  Per-font decoder construction for the encoding cascade.

  A "decoder" is a closure `(binary -> {String.t(), [{non_neg_integer(), binary()}]})`
  that maps raw font-code bytes to UTF-8 text plus a list of unresolved sentinels.

  Cascade per byte (delegates to `Pdf.Reader.Encoding.resolve_byte/3`):
  ToUnicode CMap → /Differences + AGL → base encoding → U+FFFD + sentinel.

  ## Cache

  Decoders for fonts referenced by indirect ref `{:ref, n, g}` are cached in
  `Document.cache` under key `{:font_decoder, {n, g}}` for reuse across pages
  with shared font resources. Inline font dicts (plain maps, no ref) are NOT
  cached.

  ## Spec references
  - PDF 1.7 § 9.6 — Type 1 Fonts:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.6.5, § 9.6.5.1 — Character Encoding, /Differences arrays
  - PDF 1.7 § 9.10.3 — ToUnicode CMaps
  """

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

  Returns `{:ok, %{font_name => decoder_fn}, updated_doc}`.
  """
  @spec build_decoders_for_resources(map(), Document.t()) ::
          {:ok, %{binary() => decoder_fn()}, Document.t()} | {:error, term()}
  def build_decoders_for_resources(resources, doc) do
    font_map = Map.get(resources, "Font", %{}) |> normalize_font_map()

    Enum.reduce_while(font_map, {:ok, %{}, doc}, fn {name, font_ref_or_dict},
                                                    {:ok, acc, acc_doc} ->
      case build_decoder(font_ref_or_dict, acc_doc) do
        {:ok, decoder, doc2} ->
          {:cont, {:ok, Map.put(acc, name, decoder), doc2}}

        {:error, _reason} = err ->
          {:halt, err}
      end
    end)
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
