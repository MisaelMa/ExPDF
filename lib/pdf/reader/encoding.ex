defmodule Pdf.Reader.Encoding do
  @moduledoc """
  Encoding cascade facade for resolving PDF character codes to Unicode codepoints.

  Spec reference: PDF 1.7 § 9.6.5 (Type1 encoding), § 9.10.3 (ToUnicode CMap).

  ## Cascade priority (highest first)

  1. **ToUnicode CMap** — if a `%Pdf.Reader.CMap{}` is provided and the code is mapped,
     return that codepoint immediately.
  2. **`/Differences` + AGL** — if a `/Differences` map is provided and has a glyph name
     for this byte, resolve the glyph name through the Adobe Glyph List.
  3. **Base encoding** — one of `:win_ansi`, `:mac_roman`, or `:standard` (Standard Encoding).
  4. **Unresolved fallback** — emit `{:unresolved, marker}` where `marker` is the glyph name
     (from /Differences) or `"byte:0xNN"` if no glyph name is available.

  ## `resolve_byte/3`

      resolve_byte(byte, cmap_or_nil, opts) :: {:ok, codepoint :: integer()} | {:unresolved, binary()}

  Options:
  - `:differences` — `%{integer() => glyph_name :: binary()}` or `nil`
  - `:base_encoding` — `:win_ansi | :mac_roman | :standard | nil`

  The caller substitutes `U+FFFD` for each `{:unresolved, _}` result and accumulates
  unresolved entries for the `TextRun.unresolved` field (option B shape).
  """

  alias Pdf.Reader.{AGL, CMap}
  alias Pdf.Reader.Encoding.{MacRoman, StandardEncoding, WinAnsi}

  @doc """
  Resolves a single byte to a Unicode codepoint using the encoding cascade.

  Returns `{:ok, codepoint}` on success or `{:unresolved, marker}` when no
  mapping can be found. The marker is either a glyph name (if `/Differences`
  provided one) or `"byte:0xNN"` for a raw byte with no name.
  """
  @spec resolve_byte(0..255, CMap.t() | nil, keyword()) ::
          {:ok, non_neg_integer()} | {:unresolved, binary()}
  def resolve_byte(byte, cmap, opts \\ []) do
    differences = Keyword.get(opts, :differences)
    base_encoding = Keyword.get(opts, :base_encoding)

    # Step 1: ToUnicode CMap (highest priority)
    cmap_result = try_cmap(byte, cmap)

    if cmap_result != nil do
      cmap_result
    else
      # Step 2: /Differences + AGL
      # Returns {:ok, cp} | {:unresolved, glyph_name} | nil
      # nil means: byte not covered by /Differences — fall through.
      # Non-nil means: /Differences claimed this byte (even if AGL missed it).
      diff_result = try_differences(byte, differences)

      if diff_result != nil do
        diff_result
      else
        # Step 3: Base encoding
        base_result = try_base_encoding(byte, base_encoding)

        if base_result != nil do
          base_result
        else
          # Step 4: Fallback — unresolved
          glyph_name = glyph_name_from_differences(byte, differences)

          marker =
            glyph_name ||
              "byte:0x#{Integer.to_string(byte, 16) |> String.pad_leading(2, "0") |> String.upcase()}"

          {:unresolved, marker}
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Step 1: ToUnicode CMap
  # ---------------------------------------------------------------------------

  defp try_cmap(_byte, nil), do: nil

  defp try_cmap(byte, cmap) do
    case CMap.lookup(cmap, byte) do
      nil ->
        nil

      str when is_binary(str) ->
        # The CMap returns a UTF-8 string; we need the first codepoint integer
        case String.next_codepoint(str) do
          {cp_str, _rest} ->
            <<cp::utf8>> = cp_str
            {:ok, cp}

          nil ->
            nil
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Step 2: /Differences + AGL
  # ---------------------------------------------------------------------------

  defp try_differences(_byte, nil), do: nil
  defp try_differences(_byte, differences) when map_size(differences) == 0, do: nil

  defp try_differences(byte, differences) do
    case Map.fetch(differences, byte) do
      {:ok, glyph_name} ->
        # /Differences explicitly named this byte → AGL or unresolved.
        # We do NOT fall through to base encoding when /Differences covers this byte.
        case AGL.glyph_to_unicode(glyph_name) do
          {:ok, codepoint} -> {:ok, codepoint}
          # AGL miss → still "handled" by /Differences; signal unresolved directly.
          :error -> {:unresolved, glyph_name}
        end

      :error ->
        # Byte not mentioned in /Differences → fall through to base encoding.
        nil
    end
  end

  # Helper: get glyph name from differences without resolving
  defp glyph_name_from_differences(_byte, nil), do: nil

  defp glyph_name_from_differences(byte, differences) do
    Map.get(differences, byte)
  end

  # ---------------------------------------------------------------------------
  # Step 3: Base encoding
  # ---------------------------------------------------------------------------

  defp try_base_encoding(_byte, nil), do: nil

  defp try_base_encoding(byte, :win_ansi) do
    case WinAnsi.decode(byte) do
      # WinAnsi returns 0x0000 for undefined bytes
      0 -> nil
      cp -> {:ok, cp}
    end
  end

  defp try_base_encoding(byte, :mac_roman) do
    case MacRoman.decode(byte) do
      :undefined -> nil
      cp -> {:ok, cp}
    end
  end

  defp try_base_encoding(byte, :standard) do
    case StandardEncoding.decode(byte) do
      :undefined -> nil
      cp -> {:ok, cp}
    end
  end
end
