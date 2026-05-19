defmodule Pdf.Reader.XMP do
  @moduledoc """
  XMP RDF/XML metadata parser.

  Extracts a flat `%{String.t() => String.t()}` map keyed by /Info-compatible
  names ("Title", "Author", "Subject", "Description", "Creator", "Producer",
  "CreationDate", "ModDate", "Keywords") from a catalog `/Metadata` XMP packet.

  ## Recognized namespaces (URI-based, not prefix-based)

  - `http://purl.org/dc/elements/1.1/` (dc) — Dublin Core
  - `http://ns.adobe.com/xap/1.0/` (xmp) — XMP Basic
  - `http://ns.adobe.com/pdf/1.3/` (pdf) — PDF
  - `http://www.w3.org/1999/02/22-rdf-syntax-ns#` (rdf) — RDF containers

  ## Mapping to /Info keys

  - dc:title → "Title"
  - dc:creator (rdf:Bag, **first element only**) → "Author"
  - dc:subject (rdf:Bag, first element) → "Subject"
  - dc:description (rdf:Alt) → **"Description"** (distinct from "Subject")
  - xmp:CreateDate → "CreationDate"
  - xmp:ModifyDate → "ModDate"
  - xmp:CreatorTool → "Creator"
  - pdf:Producer → "Producer"
  - pdf:Keywords → "Keywords"

  ## Error handling

  Malformed XML returns `{:error, :malformed_xmp}` — never raises. Empty
  rdf:RDF document returns `{:ok, %{}}`.

  ## Spec references
  - PDF 1.7 (ISO 32000-1) § 14.3.2 — Metadata Streams:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - XMP Specification Part 1 (data model, serialization):
    https://github.com/adobe/xmp-docs/raw/master/XMPSpecificationPart1.pdf
  - W3C RDF/XML Syntax Specification:
    https://www.w3.org/TR/rdf-syntax-grammar/
  """

  require Record

  # ---------------------------------------------------------------------------
  # Erlang :xmerl record definitions
  # ---------------------------------------------------------------------------

  Record.defrecordp(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  Record.defrecordp(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  Record.defrecordp(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  # ---------------------------------------------------------------------------
  # Namespace URI constants (atoms — xmerl uses atoms for namespace URIs when
  # namespace_conformant: true is passed to :xmerl_scan.string/2)
  # ---------------------------------------------------------------------------

  @dc :"http://purl.org/dc/elements/1.1/"
  @xmp :"http://ns.adobe.com/xap/1.0/"
  @pdf :"http://ns.adobe.com/pdf/1.3/"
  @rdf :"http://www.w3.org/1999/02/22-rdf-syntax-ns#"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec parse(binary()) :: {:ok, %{String.t() => String.t()}} | {:error, :malformed_xmp}
  def parse(xml_binary) when is_binary(xml_binary) do
    try do
      {doc, _rest} =
        :xmerl_scan.string(
          :binary.bin_to_list(xml_binary),
          document: true,
          quiet: true,
          namespace_conformant: true
        )

      {:ok, extract_from_document(doc)}
    rescue
      _ -> {:error, :malformed_xmp}
    catch
      :exit, _ -> {:error, :malformed_xmp}
    end
  end

  # ---------------------------------------------------------------------------
  # Document-level extraction
  # ---------------------------------------------------------------------------

  # xmlDocument is a 2-tuple {:xmlDocument, [root_element]}
  defp extract_from_document({:xmlDocument, children}) do
    children
    |> Enum.filter(fn node -> elem(node, 0) == :xmlElement end)
    |> Enum.reduce(%{}, fn root, acc -> Map.merge(acc, walk(root)) end)
  end

  defp extract_from_document(_), do: %{}

  # ---------------------------------------------------------------------------
  # Tree walker — recurse depth-first; accumulate key/value pairs on the way
  # ---------------------------------------------------------------------------

  defp walk(xmlElement(expanded_name: {@rdf, :RDF}, content: content)) do
    # rdf:RDF — walk into rdf:Description children
    content
    |> filter_elements()
    |> Enum.reduce(%{}, fn child, acc -> Map.merge(acc, walk(child)) end)
  end

  defp walk(xmlElement(expanded_name: {@rdf, :Description}, content: content)) do
    # rdf:Description — walk into property children
    content
    |> filter_elements()
    |> Enum.reduce(%{}, fn child, acc -> Map.merge(acc, walk(child)) end)
  end

  # dc:title → "Title" (rdf:Alt — return x-default or first)
  defp walk(xmlElement(expanded_name: {@dc, :title}, content: content)) do
    extract_property("Title", content, :alt)
  end

  # dc:creator → "Author" (rdf:Bag or rdf:Seq — first element only)
  defp walk(xmlElement(expanded_name: {@dc, :creator}, content: content)) do
    extract_property("Author", content, :first)
  end

  # dc:subject → "Subject" (rdf:Bag — first element)
  defp walk(xmlElement(expanded_name: {@dc, :subject}, content: content)) do
    extract_property("Subject", content, :first)
  end

  # dc:description → "Description" (rdf:Alt — distinct from subject)
  defp walk(xmlElement(expanded_name: {@dc, :description}, content: content)) do
    extract_property("Description", content, :alt)
  end

  # xmp:CreateDate → "CreationDate" (simple text)
  defp walk(xmlElement(expanded_name: {@xmp, :CreateDate}, content: content)) do
    extract_simple("CreationDate", content)
  end

  # xmp:ModifyDate → "ModDate" (simple text)
  defp walk(xmlElement(expanded_name: {@xmp, :ModifyDate}, content: content)) do
    extract_simple("ModDate", content)
  end

  # xmp:CreatorTool → "Creator" (simple text)
  defp walk(xmlElement(expanded_name: {@xmp, :CreatorTool}, content: content)) do
    extract_simple("Creator", content)
  end

  # pdf:Producer → "Producer" (simple text)
  defp walk(xmlElement(expanded_name: {@pdf, :Producer}, content: content)) do
    extract_simple("Producer", content)
  end

  # pdf:Keywords → "Keywords" (simple text)
  defp walk(xmlElement(expanded_name: {@pdf, :Keywords}, content: content)) do
    extract_simple("Keywords", content)
  end

  # x:xmpmeta wrapper — skip past it into children
  defp walk(xmlElement(content: content)) do
    content
    |> filter_elements()
    |> Enum.reduce(%{}, fn child, acc -> Map.merge(acc, walk(child)) end)
  end

  # ---------------------------------------------------------------------------
  # Property extraction helpers
  # ---------------------------------------------------------------------------

  # Extract a property whose value is a container (rdf:Alt, rdf:Bag, rdf:Seq).
  # :alt — x-default first, else first li
  # :first — first li text only
  defp extract_property(key, content, mode) do
    container = content |> filter_elements() |> List.first()

    value =
      case container do
        nil ->
          # No container — try treating content as simple text
          extract_text_value(content)

        xmlElement(expanded_name: {@rdf, tag}, content: li_content)
        when tag in [:Alt, :Bag, :Seq] ->
          li_elements = filter_elements(li_content)

          case mode do
            :alt ->
              # Prefer x-default lang attribute, else first
              xdefault =
                Enum.find(li_elements, fn li ->
                  attrs = xmlElement(li, :attributes)

                  Enum.any?(attrs, fn attr ->
                    xmlAttribute(attr, :value) == ~c"x-default"
                  end)
                end)

              target = xdefault || List.first(li_elements)
              if target, do: extract_text_value(xmlElement(target, :content)), else: nil

            :first ->
              first_li = List.first(li_elements)
              if first_li, do: extract_text_value(xmlElement(first_li, :content)), else: nil
          end

        _ ->
          nil
      end

    if value, do: %{key => value}, else: %{}
  end

  # Extract a simple text node (no container)
  defp extract_simple(key, content) do
    case extract_text_value(content) do
      nil -> %{}
      value -> %{key => value}
    end
  end

  # ---------------------------------------------------------------------------
  # Text value extraction
  # ---------------------------------------------------------------------------

  defp extract_text_value(content) do
    content
    |> Enum.filter(fn node -> elem(node, 0) == :xmlText end)
    |> Enum.map(fn text_node ->
      xmlText(text_node, :value)
      |> :unicode.characters_to_binary()
      |> case do
        bin when is_binary(bin) -> String.trim(bin)
        _ -> nil
      end
    end)
    |> Enum.reject(fn v -> is_nil(v) or v == "" end)
    |> List.first()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter_elements(nodes) do
    Enum.filter(nodes, fn node -> elem(node, 0) == :xmlElement end)
  end
end
