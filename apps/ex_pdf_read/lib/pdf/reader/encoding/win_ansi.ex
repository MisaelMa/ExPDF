defmodule Pdf.Reader.Encoding.WinAnsi do
  @moduledoc """
  WinAnsi (Windows-1252 / CP1252) encoding — read direction.

  Delegates to the existing `Pdf.Encoding.WinAnsi` writer module for the
  underlying character table data, exposing a single `decode/1` function
  that maps a byte (0–255) to its Unicode codepoint.

  Used by the reader when a font specifies /Encoding /WinAnsiEncoding or
  derives encoding from a Windows-origin Type 1 or TrueType font.
  """

  # Build decode/1 from Pdf.Encoding.WinAnsi.characters/0
  # characters/0 returns [{byte, unicode_codepoint, glyph_name_string}]
  # We only need {byte, unicode_codepoint} pairs where unicode is not nil.
  for {byte, unicode, _name} <- Pdf.Encoding.WinAnsi.characters(), not is_nil(unicode) do
    @doc false
    def decode(unquote(byte)), do: unquote(unicode)
  end

  # Bytes with no Unicode mapping (e.g., 0x81, 0x8D, 0x8F, 0x90, 0x9D in WinAnsi)
  # return 0x0000 as "undefined"
  def decode(_byte), do: 0x0000
end
