defmodule Pdf.Reader.Outlines do
  @moduledoc """
  Walker for catalog `/Outlines` (PDF document outline / bookmarks tree).

  Traverses the linked-list `/First`/`/Next` chain at each nesting level and
  recurses into `/First` for child outlines. A `MapSet` of `{obj_num, gen_num}`
  xref keys is threaded through the walk to prevent infinite loops when a
  corrupt PDF has cyclic `/Next` or `/First` references. A depth cap of
  `@max_outline_depth 32` ensures that arbitrarily deep trees do not overflow
  the call stack.

  ## Spec references

  - PDF 1.7 (ISO 32000-1) § 12.3.3 — Document Outline:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 12.3.2 — Destinations
  """

  alias Pdf.Reader.{Document, ObjectResolver, Destination, Outline, Utils}

  @max_outline_depth 32

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Reads the document outline tree from the PDF catalog's `/Outlines` entry.

  Returns `{:ok, outlines, doc}` where `outlines` is a (possibly empty) list
  of `%Pdf.Reader.Outline{}` structs arranged as a recursive tree.

  When the catalog has no `/Outlines` key, returns `{:ok, [], doc}` — never
  an error. The returned `doc` may have a warmer cache than the input (the
  `:page_ref_index` and `:named_dest_index` cache keys may be populated).
  """
  @spec read(Document.t()) :: {:ok, [Outline.t()], Document.t()} | {:error, term()}
  def read(doc) do
    with {:ok, catalog, doc1} <- resolve_catalog(doc) do
      case Map.get(catalog, "Outlines") do
        nil ->
          {:ok, [], doc1}

        outline_root_ref ->
          with {:ok, outline_root, doc2} <- ObjectResolver.resolve(doc1, outline_root_ref),
               {:ok, page_index, doc3} <- Destination.ensure_page_index(doc2) do
            first_ref = Map.get(outline_root, "First")
            walk(first_ref, doc3, page_index, 0, MapSet.new(), [])
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — catalog resolution
  # ---------------------------------------------------------------------------

  defp resolve_catalog(doc) do
    case Map.get(doc.trailer, "Root") do
      nil -> {:error, :no_root}
      root_ref -> ObjectResolver.resolve(doc, root_ref)
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — outline tree walker
  # ---------------------------------------------------------------------------

  # Base case: no more siblings
  defp walk(nil, doc, _page_index, _level, _visited, acc) do
    {:ok, Enum.reverse(acc), doc}
  end

  # Cycle or depth exceeded — we use a catch-all for non-ref values too
  defp walk({:ref, n, g} = ref, doc, page_index, level, visited, acc) do
    cond do
      MapSet.member?(visited, {n, g}) ->
        # Cycle detected — stop this branch; return what we have
        {:ok, Enum.reverse(acc), doc}

      level >= @max_outline_depth ->
        # Depth cap exceeded — truncate here, no error
        {:ok, Enum.reverse(acc), doc}

      true ->
        with {:ok, dict, doc1} <- ObjectResolver.resolve(doc, ref) do
          new_visited = MapSet.put(visited, {n, g})

          # Decode title
          title = Utils.decode_pdf_string(Map.get(dict, "Title"))

          # Resolve destination
          {dest_page, doc2} = resolve_dest(dict, doc1, page_index)

          # Recurse into children (/First)
          first_ref = Map.get(dict, "First")
          {:ok, children, doc3} = walk(first_ref, doc2, page_index, level + 1, new_visited, [])

          outline = %Outline{
            title: title,
            level: level,
            dest_page: dest_page,
            children: children
          }

          # Continue to siblings (/Next)
          next_ref = Map.get(dict, "Next")
          walk(next_ref, doc3, page_index, level, new_visited, [outline | acc])
        end
    end
  end

  # Non-ref value (e.g. inline dict, unexpected type) — stop walking
  defp walk(_non_ref, doc, _page_index, _level, _visited, acc) do
    {:ok, Enum.reverse(acc), doc}
  end

  # ---------------------------------------------------------------------------
  # Internal — destination resolution
  # ---------------------------------------------------------------------------

  defp resolve_dest(dict, doc, page_index) do
    dest_value = Map.get(dict, "Dest") || Map.get(dict, "A")

    if dest_value do
      case Destination.resolve(dest_value, doc, page_index) do
        {:ok, page, doc1} -> {page, doc1}
        # Destination.resolve/3 never errors per spec R-AO13; this is a safety net
        _error -> {nil, doc}
      end
    else
      {nil, doc}
    end
  end
end
