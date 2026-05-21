defmodule Pdf.Reader.Annotations do
  @moduledoc """
  Walker for per-page `/Annots` arrays.

  Iterates each page; resolves each annotation ref; dispatches by `/Subtype`
  to type-specific extraction to build `%Pdf.Reader.Annotation{}` structs.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 12.5 — Annotations:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 12.5.6.x — Annotation types (Link, Text, Highlight, Underline,
    StrikeOut, Squiggly, Square, Circle, FreeText, FileAttachment)
  - PDF 1.7 § 12.6 — Actions
  """

  alias Pdf.Reader.{Document, ObjectResolver, Page, Destination, Annotation, Utils}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Reads all annotations from all pages in the document.

  Returns `{:ok, [Annotation.t()], doc}` where annotations are ordered
  page-ascending. When no page has an `/Annots` array, returns `{:ok, [], doc}`.

  The returned `doc` may have a warmer cache than the input.
  """
  @spec read(Document.t()) :: {:ok, [Annotation.t()], Document.t()} | {:error, term()}
  def read(doc) do
    with {:ok, page_refs, doc1} <- Page.list_refs(doc),
         {:ok, page_index, doc2} <- Destination.ensure_page_index(doc1) do
      walk_pages(page_refs, doc2, page_index, 1, [])
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — page walker
  # ---------------------------------------------------------------------------

  defp walk_pages([], doc, _page_index, _page_num, acc) do
    {:ok, Enum.reverse(acc), doc}
  end

  defp walk_pages([{n, g} | rest], doc, page_index, page_num, acc) do
    case ObjectResolver.resolve(doc, {:ref, n, g}) do
      {:ok, page_dict, doc1} ->
        case Map.get(page_dict, "Annots") do
          nil ->
            walk_pages(rest, doc1, page_index, page_num + 1, acc)

          annots when is_list(annots) ->
            {anns, doc2} = walk_annots(annots, doc1, page_index, page_num, [])
            walk_pages(rest, doc2, page_index, page_num + 1, anns ++ acc)

          _ ->
            walk_pages(rest, doc1, page_index, page_num + 1, acc)
        end

      _ ->
        walk_pages(rest, doc, page_index, page_num + 1, acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — annotation walker
  # ---------------------------------------------------------------------------

  defp walk_annots([], doc, _page_index, _page_num, acc) do
    {Enum.reverse(acc), doc}
  end

  defp walk_annots([ref | rest], doc, page_index, page_num, acc) do
    case ObjectResolver.resolve(doc, ref) do
      {:ok, dict, doc1} when is_map(dict) ->
        {annotation, doc2} = build_annotation(dict, page_num, doc1, page_index)
        walk_annots(rest, doc2, page_index, page_num, [annotation | acc])

      _ ->
        walk_annots(rest, doc, page_index, page_num, acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — annotation builder
  # ---------------------------------------------------------------------------

  defp build_annotation(dict, page_num, doc, page_index) do
    type = subtype_to_atom(Map.get(dict, "Subtype"))
    rect = Utils.parse_rect(Map.get(dict, "Rect"))
    contents = Utils.decode_pdf_string(Map.get(dict, "Contents"))
    title = Utils.decode_pdf_string(Map.get(dict, "T"))
    subject = Utils.decode_pdf_string(Map.get(dict, "Subj"))
    created = Utils.decode_pdf_string(Map.get(dict, "CreationDate"))
    modified = Utils.decode_pdf_string(Map.get(dict, "M"))

    {dest_page, doc1} = resolve_dest(dict, doc, page_index)
    url = extract_url(dict)
    embedded = extract_embedded_file(dict)
    kind_specific = extract_kind_specific(type, dict)

    annotation = %Annotation{
      type: type,
      page: page_num,
      rect: rect,
      contents: contents,
      title: title,
      subject: subject,
      created: created,
      modified: modified,
      dest_page: dest_page,
      url: url,
      embedded_file_ref: embedded,
      kind_specific: kind_specific
    }

    {annotation, doc1}
  end

  # ---------------------------------------------------------------------------
  # Internal — subtype dispatch
  # ---------------------------------------------------------------------------

  defp subtype_to_atom({:name, "Link"}), do: :link
  defp subtype_to_atom({:name, "Text"}), do: :text
  defp subtype_to_atom({:name, "Highlight"}), do: :highlight
  defp subtype_to_atom({:name, "Underline"}), do: :underline
  defp subtype_to_atom({:name, "StrikeOut"}), do: :strikeout
  defp subtype_to_atom({:name, "Squiggly"}), do: :squiggly
  defp subtype_to_atom({:name, "Square"}), do: :square
  defp subtype_to_atom({:name, "Circle"}), do: :circle
  defp subtype_to_atom({:name, "FreeText"}), do: :freetext
  defp subtype_to_atom({:name, "FileAttachment"}), do: :file_attachment
  defp subtype_to_atom(_), do: :unknown

  # ---------------------------------------------------------------------------
  # Internal — destination resolution (page number)
  # ---------------------------------------------------------------------------

  defp resolve_dest(dict, doc, page_index) do
    dest =
      case Map.get(dict, "Dest") do
        nil -> Map.get(dict, "A")
        d -> d
      end

    case dest do
      nil ->
        {nil, doc}

      d ->
        case Destination.resolve(d, doc, page_index) do
          {:ok, page_num, doc1} -> {page_num, doc1}
          # Destination.resolve/3 never errors per spec (R-AO13); safety net kept
          # intentionally so any future return-type widening doesn't crash here.
          _ -> {nil, doc}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — URL extraction (URI actions only, never a page dest)
  # ---------------------------------------------------------------------------

  defp extract_url(dict) do
    case Map.get(dict, "A") do
      %{"S" => {:name, "URI"}, "URI" => uri_value} ->
        Utils.decode_pdf_string(uri_value)

      _ ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — embedded file ref extraction
  # ---------------------------------------------------------------------------

  defp extract_embedded_file(dict) do
    case Map.get(dict, "FS") do
      %{"EF" => %{"F" => {:ref, _, _} = ref}} -> ref
      _ -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — kind-specific data by subtype
  # ---------------------------------------------------------------------------

  defp extract_kind_specific(type, dict)
       when type in [:highlight, :underline, :strikeout, :squiggly] do
    case Map.get(dict, "QuadPoints") do
      pts when is_list(pts) ->
        tuples =
          pts
          |> Enum.map(&to_float/1)
          |> Enum.chunk_every(8, 8, :discard)
          |> Enum.map(&List.to_tuple/1)

        %{quad_points: tuples}

      _ ->
        %{}
    end
  end

  defp extract_kind_specific(:text, dict) do
    %{open: Map.get(dict, "Open", false), name: Map.get(dict, "Name")}
  end

  defp extract_kind_specific(:unknown, dict), do: dict

  defp extract_kind_specific(_, _), do: %{}

  # ---------------------------------------------------------------------------
  # Internal — helpers
  # ---------------------------------------------------------------------------

  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_float(n), do: n
  defp to_float(n), do: n
end
