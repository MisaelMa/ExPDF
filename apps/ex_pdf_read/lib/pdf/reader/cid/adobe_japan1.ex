defmodule Pdf.Reader.CID.AdobeJapan1 do
  @moduledoc """
  Adobe-Japan1 CID to Unicode mapping (~9600 entries).

  Bundled at compile time from `priv/adobe-japan1-cid2unicode.txt`,
  normalized from the `cid2code.txt` table in the `cmap-resources` repository
  (Adobe-Japan1-7/cid2code.txt, UniJIS-UCS2 column).

  Each entry generates a pattern-match clause (O(1) BEAM dispatch).

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 9.7 — Composite Fonts:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 9.7.4 — CIDFonts
  - PDF 1.7 § 9.7.5 — CMaps (Identity-H, Identity-V predefined)
  - Adobe-Japan1 collection: https://github.com/adobe-type-tools/Adobe-Japan1
  - CMap resources (source data): https://github.com/adobe-type-tools/cmap-resources
  """

  @priv_path Path.join([:code.priv_dir(:ex_pdf_read), "adobe-japan1-cid2unicode.txt"])
  @external_resource @priv_path

  @doc """
  Returns `{:ok, codepoint}` for known CIDs, `:error` for unknown ones.

  Codepoint is a Unicode scalar value (non_neg_integer).
  """
  @spec lookup(non_neg_integer()) :: {:ok, non_neg_integer()} | :error
  for line <- File.stream!(@priv_path) do
    trimmed = String.trim(line)

    case Regex.run(~r/^(\d+);([0-9A-Fa-f]+)$/, trimmed) do
      [_, cid_str, hex] ->
        cid = String.to_integer(cid_str)
        codepoint = String.to_integer(hex, 16)
        def lookup(unquote(cid)), do: {:ok, unquote(codepoint)}

      _ ->
        :ok
    end
  end

  def lookup(_), do: :error
end
