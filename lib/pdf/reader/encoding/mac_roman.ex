defmodule Pdf.Reader.Encoding.MacRoman do
  @moduledoc """
  Mac OS Roman (MacRomanEncoding) byte-to-Unicode codepoint table.

  Used by PDF readers to decode single-byte character codes for fonts
  that specify `/Encoding /MacRomanEncoding` (or omit an encoding and
  use a Mac-origin Type 1 font).

  The table is generated at compile time from `priv/mac_roman.txt`,
  which is the canonical mapping published by Apple at
  <https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/ROMAN.TXT>.
  Bytes that are not present in the source file return `:undefined`.
  """

  @external_resource Path.join([:code.priv_dir(:ex_pdf), "mac_roman.txt"])

  @table @external_resource
         |> File.read!()
         |> String.split("\n")
         |> Enum.flat_map(fn line ->
           case Regex.run(~r/^0x([0-9A-Fa-f]{2})\s+0x([0-9A-Fa-f]{4})/, line) do
             [_, byte_hex, code_hex] ->
               [{String.to_integer(byte_hex, 16), String.to_integer(code_hex, 16)}]

             _ ->
               []
           end
         end)

  @doc "Returns the number of byte→codepoint entries loaded from priv/mac_roman.txt."
  @spec entry_count() :: non_neg_integer()
  def entry_count, do: unquote(length(@table))

  @doc """
  Decode a single byte to a Unicode codepoint.

  Returns `:undefined` for bytes that have no mapping in Mac OS Roman.
  """
  @spec decode(0..255) :: non_neg_integer() | :undefined
  for {byte, codepoint} <- @table do
    def decode(unquote(byte)), do: unquote(codepoint)
  end

  def decode(byte) when is_integer(byte) and byte in 0..255, do: :undefined
end
