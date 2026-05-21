defmodule Pdf.Reader.Destination do
  @moduledoc """
  Destination resolution for outline and annotation `/Dest` values.

  Handles 4 variants:
  1. Direct array `[<page-ref> /XYZ x y zoom]` — first element is a page ref.
  2. Named string — looked up in catalog `/Names /Dests` name tree.
  3. `/A /S /GoTo /D <array>` — array variant inside an action dict.
  4. `/A /S /GoTo /D <name>` — named variant inside an action dict.

  Unresolvable destinations return `{:ok, nil, doc}` — no error is raised.

  ## Spec references

  - PDF 1.7 § 12.3.2 — Destinations:
    https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
  - PDF 1.7 § 12.6 — Actions
  - PDF 1.7 § 7.9.6 — Name Trees
  """

  alias Pdf.Reader.{Document, ObjectResolver, Page}

  @max_name_tree_depth 20

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Resolves a destination value to a 1-indexed page number.

  Accepts any of the 4 dest variants described in the moduledoc. Returns
  `{:ok, page_num, doc}` where `page_num` is a positive integer or `nil`
  when the destination cannot be resolved.

  The returned `doc` may have a warmer cache than the input.

  ## Parameters

  - `dest` — the raw dest value from the PDF dict (see variants above)
  - `doc` — the `%Pdf.Reader.Document{}` to resolve against
  - `page_index` — a `%{{obj_num, gen_num} => page_num_1indexed}` map;
    obtain via `ensure_page_index/1`
  """
  @spec resolve(any(), Document.t(), %{{pos_integer(), non_neg_integer()} => pos_integer()}) ::
          {:ok, pos_integer() | nil, Document.t()}
  def resolve(dest, doc, page_index) do
    case dest do
      # Variant 1: direct array — first element is a page ref
      [{:ref, n, g} | _] ->
        {:ok, Map.get(page_index, {n, g}), doc}

      # Variant 2a: named string dest
      {:string, name} ->
        resolve_named(name, doc, page_index)

      # Variant 2b: hex string (same lookup path)
      {:hex_string, name} ->
        resolve_named(name, doc, page_index)

      # Variants 3 & 4: action dict with GoTo
      %{} = action_dict ->
        resolve_action(action_dict, doc, page_index)

      # Fallback: nil, integers, atoms, empty lists, etc.
      _ ->
        {:ok, nil, doc}
    end
  end

  @doc """
  Ensures the page-ref index is built and returns it.

  The index maps `{obj_num, gen_num}` refs to 1-indexed page numbers.
  The result is cached in `doc.cache[:page_ref_index]` — subsequent calls
  return the cached value without re-traversing the page tree.

  ## Example

      {:ok, index, doc} = Pdf.Reader.Destination.ensure_page_index(doc)
      page_num = Map.get(index, {3, 0})  # => 1
  """
  @spec ensure_page_index(Document.t()) ::
          {:ok, %{{pos_integer(), non_neg_integer()} => pos_integer()}, Document.t()}
  def ensure_page_index(doc) do
    case Map.get(doc.cache, :page_ref_index) do
      nil ->
        with {:ok, page_refs, doc1} <- Page.list_refs(doc) do
          index = page_refs |> Enum.with_index(1) |> Map.new()
          doc2 = put_cache(doc1, :page_ref_index, index)
          {:ok, index, doc2}
        end

      cached ->
        {:ok, cached, doc}
    end
  end

  @doc """
  Builds (and caches) a flat `%{name => dest_array}` map from the catalog's
  `/Names /Dests` name tree.

  The result is cached in `doc.cache[:named_dest_index]`. If the catalog has
  no `/Names` or `/Dests` entry, returns `{:ok, %{}, doc}`.

  Name tree traversal:
  - Visits ALL `/Kids` (does NOT binary-search via `/Limits` — corrupt PDFs
    may violate sort order).
  - Depth cap: `@max_name_tree_depth 20` — nodes beyond depth 20 are skipped.
  - Cycle guard: `MapSet` of `{obj_num, gen_num}` to prevent infinite loops.
  """
  @spec build_named_dest_index(Document.t()) :: {:ok, %{String.t() => list()}, Document.t()}
  def build_named_dest_index(doc) do
    case Map.get(doc.cache, :named_dest_index) do
      nil ->
        walk_name_tree(doc)

      cached ->
        {:ok, cached, doc}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — action dict dispatch
  # ---------------------------------------------------------------------------

  # GoTo with array dest
  defp resolve_action(%{"S" => {:name, "GoTo"}, "D" => d}, doc, page_index),
    do: resolve(d, doc, page_index)

  # URI action — not a page destination
  defp resolve_action(%{"S" => {:name, "URI"}}, doc, _page_index),
    do: {:ok, nil, doc}

  # All other action types
  defp resolve_action(_action, doc, _page_index),
    do: {:ok, nil, doc}

  # ---------------------------------------------------------------------------
  # Internal — named dest resolution
  # ---------------------------------------------------------------------------

  defp resolve_named(name, doc, page_index) do
    with {:ok, index, doc1} <- build_named_dest_index(doc) do
      case Map.get(index, name) do
        nil -> {:ok, nil, doc1}
        dest_array -> resolve(dest_array, doc1, page_index)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — name tree walker
  # ---------------------------------------------------------------------------

  defp walk_name_tree(doc) do
    with {:ok, catalog, doc1} <- resolve_catalog(doc),
         {:ok, dests_root_ref, doc2} <- find_dests_root(catalog, doc1) do
      {index, doc3} = walk_node(dests_root_ref, doc2, 0, MapSet.new(), %{})
      {:ok, index, put_cache(doc3, :named_dest_index, index)}
    else
      {:no_dests, doc_out} ->
        {:ok, %{}, put_cache(doc_out, :named_dest_index, %{})}

      {:error, _reason} ->
        {:ok, %{}, put_cache(doc, :named_dest_index, %{})}
    end
  end

  defp resolve_catalog(doc) do
    case Map.get(doc.trailer, "Root") do
      nil -> {:error, :no_catalog}
      root_ref -> ObjectResolver.resolve(doc, root_ref)
    end
  end

  defp find_dests_root(catalog, doc) when is_map(catalog) do
    case Map.get(catalog, "Names") do
      nil ->
        {:no_dests, doc}

      names_ref when is_tuple(names_ref) ->
        case ObjectResolver.resolve(doc, names_ref) do
          {:ok, names_dict, doc2} when is_map(names_dict) ->
            case Map.get(names_dict, "Dests") do
              nil -> {:no_dests, doc2}
              dests_ref -> {:ok, dests_ref, doc2}
            end

          {:error, _} ->
            {:no_dests, doc}
        end

      names_dict when is_map(names_dict) ->
        case Map.get(names_dict, "Dests") do
          nil -> {:no_dests, doc}
          dests_ref -> {:ok, dests_ref, doc}
        end
    end
  end

  defp find_dests_root(_catalog, doc), do: {:no_dests, doc}

  # Walk a node — accepts a ref or a resolved dict
  defp walk_node(_ref_or_dict, doc, depth, _visited, acc)
       when depth > @max_name_tree_depth do
    # Depth cap exceeded — skip this subtree
    {acc, doc}
  end

  defp walk_node({:ref, n, g} = ref, doc, depth, visited, acc) do
    key = {n, g}

    if MapSet.member?(visited, key) do
      # Cycle detected — skip
      {acc, doc}
    else
      visited2 = MapSet.put(visited, key)

      case ObjectResolver.resolve(doc, ref) do
        {:ok, node_dict, doc2} when is_map(node_dict) ->
          walk_node_dict(node_dict, doc2, depth, visited2, acc)

        _ ->
          {acc, doc}
      end
    end
  end

  defp walk_node(node_dict, doc, depth, visited, acc) when is_map(node_dict) do
    walk_node_dict(node_dict, doc, depth, visited, acc)
  end

  defp walk_node(_other, doc, _depth, _visited, acc) do
    {acc, doc}
  end

  defp walk_node_dict(node_dict, doc, depth, visited, acc) do
    cond do
      # Leaf node — has /Names [name, dest, name, dest, ...]
      Map.has_key?(node_dict, "Names") ->
        names_list = Map.get(node_dict, "Names", [])
        new_acc = collect_names(names_list, acc)
        {new_acc, doc}

      # Intermediate node — has /Kids [ref, ref, ...]
      Map.has_key?(node_dict, "Kids") ->
        kids = Map.get(node_dict, "Kids", [])

        Enum.reduce(kids, {acc, doc}, fn kid_ref, {acc_in, doc_in} ->
          walk_node(kid_ref, doc_in, depth + 1, visited, acc_in)
        end)

      true ->
        {acc, doc}
    end
  end

  # Collect paired [name, dest] entries from the /Names array
  defp collect_names([], acc), do: acc

  defp collect_names([name_val, dest | rest], acc) do
    name_str = extract_name_string(name_val)

    new_acc =
      if name_str do
        Map.put(acc, name_str, dest)
      else
        acc
      end

    collect_names(rest, new_acc)
  end

  defp collect_names([_single], acc), do: acc

  # Extract a plain string from various PDF string representations
  defp extract_name_string({:string, bin}) when is_binary(bin), do: bin
  defp extract_name_string({:hex_string, bin}) when is_binary(bin), do: bin
  defp extract_name_string(bin) when is_binary(bin), do: bin
  defp extract_name_string(_), do: nil

  # ---------------------------------------------------------------------------
  # Internal — cache helpers
  # ---------------------------------------------------------------------------

  defp put_cache(doc, key, value) do
    %{doc | cache: Map.put(doc.cache, key, value)}
  end
end
