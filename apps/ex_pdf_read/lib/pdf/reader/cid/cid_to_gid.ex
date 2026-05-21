defmodule Pdf.Reader.CID.CIDToGIDMap do
  @moduledoc """
  Parser and lookup for the PDF `/CIDToGIDMap` entry in Type2 CIDFont dicts.

  `/CIDToGIDMap` maps CIDs to GIDs (glyph indices) in the referenced CIDFont
  program. This module parses it and stores the result for future glyph-rendering
  work. It is NOT used in the Unicode resolution cascade — the cascade goes
  CID → Unicode directly via the registry tables.

  ## Supported forms

  - `{:name, "Identity"}` — GID == CID for all characters.
  - `{:stream, dict, raw_bytes}` — FlateDecode-decoded binary of uint16-BE pairs.
  - `{:ref, n, g}` — indirect reference resolved via `Pdf.Reader.ObjectResolver`.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.7.4 — CIDFonts (/CIDToGIDMap key description)
  - PDF 1.7 § 9.7.5 — Predefined CMaps (Identity-H/V context)
  """

  alias Pdf.Reader.{Document, Filter, ObjectResolver}

  @doc """
  Parse a `/CIDToGIDMap` PDF value into an internal representation.

  Returns:
  - `{:ok, :identity, doc}` for `{:name, "Identity"}`
  - `{:ok, {:stream_map, binary}, doc}` for stream values (decoded)
  - `{:error, :malformed}` for unrecognised values
  """
  @spec parse(any(), Document.t()) ::
          {:ok, :identity | {:stream_map, binary()}, Document.t()} | {:error, :malformed}
  def parse({:name, "Identity"}, doc), do: {:ok, :identity, doc}

  def parse({:ref, _, _} = ref, doc) do
    case ObjectResolver.resolve(doc, ref) do
      {:ok, {:stream, dict, raw_bytes}, doc1} ->
        decode_stream_map(dict, raw_bytes, doc1)

      _ ->
        {:error, :malformed}
    end
  end

  def parse({:stream, dict, raw_bytes}, doc) do
    decode_stream_map(dict, raw_bytes, doc)
  end

  def parse(_other, _doc), do: {:error, :malformed}

  @doc """
  Look up a CID in a parsed CIDToGIDMap.

  Returns `{:ok, gid}` or `:error`.

  - `:identity` — GID == CID always.
  - `{:stream_map, bytes}` — binary offset at `cid * 2`, decoded as big-endian uint16.
  """
  @spec lookup(:identity | {:stream_map, binary()}, non_neg_integer()) ::
          {:ok, non_neg_integer()} | :error
  def lookup(:identity, cid), do: {:ok, cid}

  def lookup({:stream_map, bytes}, cid) do
    offset = cid * 2

    case bytes do
      <<_::binary-size(offset), gid::big-unsigned-16, _::binary>> -> {:ok, gid}
      _ -> :error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp decode_stream_map(dict, raw_bytes, doc) do
    filter = Map.get(dict, "Filter")
    decode_parms = Map.get(dict, "DecodeParms")

    case apply_filter(raw_bytes, filter, decode_parms) do
      {:ok, decoded} -> {:ok, {:stream_map, decoded}, doc}
      {:error, _} -> {:error, :malformed}
    end
  end

  defp apply_filter(raw_bytes, nil, _parms), do: {:ok, raw_bytes}

  defp apply_filter(raw_bytes, filter, parms) do
    Filter.apply_chain(raw_bytes, filter, parms || %{})
  end
end
