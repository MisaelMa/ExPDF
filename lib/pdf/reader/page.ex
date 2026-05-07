defmodule Pdf.Reader.Page do
  @moduledoc """
  Page tree walker for `Pdf.Reader`.

  Spec reference: PDF 1.7 § 7.7.3 (Page Tree).

  ## Page tree structure

  The Catalog's `/Pages` entry points to the root of the page tree.
  A node with `/Type /Pages` is an intermediate node containing a `/Kids`
  array of refs to child nodes (either `/Pages` or `/Page`).
  A node with `/Type /Page` is a leaf — one actual page.

  ## API

      list_refs(doc) :: {:ok, [ref], updated_doc} | {:error, reason}

  Walks the tree recursively, collecting leaf `/Page` refs in document order.
  Threads `doc` forward so that resolved objects accumulate in the cache.
  """

  alias Pdf.Reader.{Document, ObjectResolver}

  @doc """
  Walks the page tree and returns a list of leaf `/Page` object refs in order.

  Returns `{:ok, refs, updated_doc}` where:
  - `refs` is `[{obj_num, gen_num}]` in page order
  - `updated_doc` has cache populated from the traversal

  Returns `{:error, reason}` if the page tree cannot be traversed.
  """
  @spec list_refs(Document.t()) ::
          {:ok, [Document.ref()], Document.t()} | {:error, term()}
  def list_refs(%Document{trailer: trailer} = doc) do
    case Map.get(trailer, "Root") do
      nil ->
        {:error, :no_pages}

      root_ref ->
        with {:ok, catalog, doc2} <- ObjectResolver.resolve(doc, root_ref),
             {:ok, pages_ref} <- fetch_pages_ref(catalog),
             {:ok, refs, doc3} <- walk_kids(doc2, pages_ref) do
          {:ok, refs, doc3}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  defp fetch_pages_ref(catalog) when is_map(catalog) do
    case Map.get(catalog, "Pages") do
      nil -> {:error, :no_pages}
      ref -> {:ok, ref}
    end
  end

  defp fetch_pages_ref(_), do: {:error, :no_pages}

  # Resolve a ref and dispatch on /Type
  defp walk_kids(doc, {:ref, _, _} = ref) do
    case ObjectResolver.resolve(doc, ref) do
      {:ok, node, doc2} -> walk_node(doc2, ref, node)
      {:error, _} = err -> err
    end
  end

  # Walk an already-resolved node — just dispatch on type
  defp walk_node(doc, ref, node) when is_map(node) do
    case Map.get(node, "Type") do
      {:name, "Pages"} -> walk_pages_node(doc, node)
      {:name, "Page"} -> {:ok, [ref_key(ref)], doc}
      # Fallback: if a Kids array exists treat as intermediate
      _ when is_map_key(node, "Kids") -> walk_pages_node(doc, node)
      _ -> {:error, {:malformed, :page_tree, %{unexpected_type: Map.get(node, "Type")}}}
    end
  end

  defp walk_node(_doc, _ref, other),
    do: {:error, {:malformed, :page_tree, %{expected_dict: other}}}

  # Walk a /Pages intermediate node: iterate Kids, collect leaf refs
  defp walk_pages_node(doc, %{"Kids" => kids}) when is_list(kids) do
    Enum.reduce_while(kids, {:ok, [], doc}, fn kid_ref, {:ok, acc_refs, acc_doc} ->
      case walk_kids(acc_doc, kid_ref) do
        {:ok, new_refs, updated_doc} -> {:cont, {:ok, acc_refs ++ new_refs, updated_doc}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp walk_pages_node(_doc, node),
    do: {:error, {:malformed, :page_tree, %{missing_kids: node}}}

  # Extract the {n, g} key from a ref tuple
  defp ref_key({:ref, n, g}), do: {n, g}
  defp ref_key({n, g}), do: {n, g}
end
