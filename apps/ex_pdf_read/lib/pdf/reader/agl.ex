defmodule Pdf.Reader.AGL do
  @moduledoc """
  Adobe Glyph List (AGL) — compile-time glyph name to Unicode codepoint lookup.

  Bundled from the Adobe Glyph List 2.0 (2002), available at:
  https://github.com/adobe-type-tools/agl-aglfn

  Licensed under the BSD-style permissive license reproduced in the header of
  `priv/glyphlist.txt`.

  ## Usage

      iex> Pdf.Reader.AGL.glyph_to_unicode("eacute")
      {:ok, 0x00E9}

      iex> Pdf.Reader.AGL.glyph_to_unicode("notaname")
      :error

  ## Notes

  - Only the FIRST codepoint of multi-codepoint entries is returned (ligatures
    such as `fi` map to their decomposed form's first character). This is
    sufficient for single-glyph font-encoding lookups.
  - All ~4500 entries are compiled to BEAM pattern-match clauses at build time
    for O(1) lookup performance during text extraction.
  """

  @external_resource Path.join([__DIR__, "..", "..", "..", "priv", "glyphlist.txt"])
  @glyphlist_path Path.join([__DIR__, "..", "..", "..", "priv", "glyphlist.txt"])

  for line <- File.stream!(@glyphlist_path),
      not String.starts_with?(line, "#"),
      String.trim(line) != "",
      [name, hex_part] = String.split(String.trim(line), ";", parts: 2) do
    # Some entries have multiple space-separated codepoints (ligatures);
    # take only the first for single-glyph resolution.
    first_hex = hex_part |> String.split(" ") |> hd() |> String.trim()
    codepoint = String.to_integer(first_hex, 16)

    @doc false
    def glyph_to_unicode(unquote(name)), do: {:ok, unquote(codepoint)}
  end

  @doc """
  Look up a PostScript glyph name and return its Unicode codepoint.

  Returns `{:ok, codepoint}` for known names, `:error` for unknown ones.
  """
  @spec glyph_to_unicode(binary()) :: {:ok, non_neg_integer()} | :error
  def glyph_to_unicode(_name), do: :error
end
