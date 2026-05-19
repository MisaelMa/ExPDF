defmodule Pdf.Reader.Encoding.StandardEncoding do
  @moduledoc """
  PDF Standard Encoding — byte-to-Unicode codepoint table.

  Used for fonts that specify `/Encoding /StandardEncoding` (or omit
  an explicit encoding and use a Type 1 font with default encoding).

  The byte→glyph-name table is generated from `priv/standard_encoding.txt`
  (PDF 1.7 ISO 32000-1, Annex D.2 Table D.2; cross-checked against
  Mozilla pdf.js, Apache-2.0). Glyph names are resolved to Unicode
  codepoints at compile time via the Adobe Glyph List
  (`priv/glyphlist.txt`). Bytes that have no entry return `:undefined`.
  """

  @glyphlist_path Path.join([:code.priv_dir(:ex_pdf_read), "glyphlist.txt"])
  @encoding_path Path.join([:code.priv_dir(:ex_pdf_read), "standard_encoding.txt"])

  @external_resource @glyphlist_path
  @external_resource @encoding_path

  @glyph_to_unicode @glyphlist_path
                    |> File.read!()
                    |> String.split("\n")
                    |> Enum.flat_map(fn line ->
                      case Regex.run(~r/^([A-Za-z][A-Za-z0-9._]*);([0-9A-Fa-f]{4})\b/, line) do
                        [_, name, hex] -> [{name, String.to_integer(hex, 16)}]
                        _ -> []
                      end
                    end)
                    |> Map.new()

  @table @encoding_path
         |> File.read!()
         |> String.split("\n")
         |> Enum.flat_map(fn line ->
           case Regex.run(~r/^0x([0-9A-Fa-f]{2})\s+([A-Za-z][A-Za-z0-9._]*)\s*$/, line) do
             [_, byte_hex, name] ->
               byte = String.to_integer(byte_hex, 16)

               case Map.fetch(@glyph_to_unicode, name) do
                 {:ok, code} ->
                   [{byte, code}]

                 :error ->
                   raise "StandardEncoding: glyph #{inspect(name)} (byte 0x#{byte_hex}) not found in priv/glyphlist.txt"
               end

             _ ->
               []
           end
         end)

  @doc "Returns the number of byte→codepoint entries loaded at compile time."
  @spec entry_count() :: non_neg_integer()
  def entry_count, do: unquote(length(@table))

  @doc """
  Decode a single byte to a Unicode codepoint.

  Returns `:undefined` for bytes that have no mapping in PDF Standard Encoding.
  """
  @spec decode(0..255) :: non_neg_integer() | :undefined
  for {byte, codepoint} <- @table do
    def decode(unquote(byte)), do: unquote(codepoint)
  end

  def decode(byte) when is_integer(byte) and byte in 0..255, do: :undefined
end
