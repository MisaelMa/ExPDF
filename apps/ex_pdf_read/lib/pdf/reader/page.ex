defmodule Pdf.Reader.Page do
  @moduledoc """
  Page tree walker for `Pdf.Reader`.

  Spec reference: PDF 1.7 § 7.7.3 (Page Tree), § 7.7.3.4 (Inheritance of Page Attributes).

  ## Page tree structure

  The Catalog's `/Pages` entry points to the root of the page tree.
  A node with `/Type /Pages` is an intermediate node containing a `/Kids`
  array of refs to child nodes (either `/Pages` or `/Page`).
  A node with `/Type /Page` is a leaf — one actual page.

  ## API

      list_refs(doc) :: {:ok, [ref], updated_doc} | {:error, reason}

  Walks the tree recursively, collecting leaf `/Page` refs in document order.
  Threads `doc` forward so that resolved objects accumulate in the cache.

  ## Catalog/Pages tree fallback (R-4)

  When `doc.recover_mode` is `true` and the normal tree walk fails (missing
  `/Root`, dangling `/Pages` ref, or other catalog resolution error), the
  recovery branch scans the xref table directly for objects that match ALL of:

  - `/Type /Page` in the object dict
  - Either `/Contents` OR `/Parent` present (disambiguates from Form XObjects
    which also carry `/Type /XObject /Subtype /Form`)

  The recovered list is in xref-insertion order, NOT document order. This
  known limitation is by design — reconstruction from corrupt trees is
  unreliable. A `{:page_tree_recovered, n}` event is appended to the
  `recovery_log` so callers know page order may differ.

  ## Known limitations (R-4)

  - **Page order loss** — catalog-fallback page order follows xref-insertion
    order, not the original document order. `/Parent` chain reconstruction is
    not attempted (unreliable on corrupt trees). The `{:page_tree_recovered, n}`
    event explicitly signals this to callers.

  - **Encrypted AND corrupted PDFs** — when both the xref table and the catalog
    are corrupt, the R-3 linear scan reconstructs the xref but cannot include
    `/Encrypt` in the synthetic trailer. Without `/Encrypt`, decryption cannot
    proceed and the PDF is non-decryptable even with `recover: true`.

  Spec citations:
  - PDF 1.7 § 7.7.2 — Document catalog (Catalog dict, /Pages entry)
  - PDF 1.7 § 7.7.3 — Page tree (/Pages /Kids traversal)
  - PDF 1.7 § 7.7.3.4 — Inheritance of page attributes
  """

  alias Pdf.Reader.{Document, ObjectResolver}

  # `ref_key/1` and `extract_kid_key/1` keep a defensive fallback clause that
  # accepts already-unwrapped `{n, g}` tuples (or any other shape, in
  # `extract_kid_key/1`'s case). Dialyzer's success-typing on the call sites
  # proves the input is always a parser-emitted `{:ref, _, _}` tuple — the
  # fallback is unreachable today but cheap insurance against parser shape
  # widening in the future. Silence the "pattern can never match" warnings.
  # Reference for the wrap convention: PDF 1.7 § 7.3.10 (indirect references).
  @dialyzer {:nowarn_function, ref_key: 1, extract_kid_key: 1}

  @doc """
  Walks the page tree and returns a list of leaf `/Page` object refs in order.

  Returns `{:ok, refs, updated_doc}` where:
  - `refs` is `[{obj_num, gen_num}]` in page order (or xref order in fallback)
  - `updated_doc` has cache populated from the traversal

  Returns `{:error, reason}` if the page tree cannot be traversed and
  `recover_mode` is `false`.

  When `recover_mode` is `true` and traversal fails, falls back to xref scan
  and appends `{:page_tree_recovered, n}` to `recovery_log`.
  """
  @spec list_refs(Document.t()) ::
          {:ok, [Document.ref()], Document.t()} | {:error, term()}
  def list_refs(%Document{} = doc) do
    # If page_refs were already resolved and cached (e.g. by the R-4 probe in
    # do_open/2 when recover_mode: true), return them immediately without
    # re-walking the tree.
    case doc.page_refs do
      refs when is_list(refs) and refs != [] ->
        {:ok, refs, doc}

      _ ->
        case strict_list_refs(doc) do
          {:ok, refs, doc2} ->
            {:ok, refs, doc2}

          {:error, reason} when doc.recover_mode ->
            recover_pages(doc, reason)

          {:error, _} = err ->
            err
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — strict tree walk
  # ---------------------------------------------------------------------------

  defp strict_list_refs(%Document{trailer: trailer} = doc) do
    case Map.get(trailer, "Root") do
      nil ->
        {:error, :no_pages}

      root_ref ->
        with {:ok, catalog, doc2} <- ObjectResolver.resolve(doc, root_ref),
             {:ok, pages_ref} <- fetch_pages_ref_or_self(root_ref, catalog) do
          walk_kids(doc2, pages_ref)
        end
    end
  end

  # Attempt to fetch the /Pages ref from the catalog dict.
  # If the root dict IS itself a /Pages node (no Catalog wrapper — some legacy PDFs),
  # return the root ref directly so the walker treats it as the pages tree root.
  defp fetch_pages_ref_or_self(root_ref, catalog) when is_map(catalog) do
    case Map.get(catalog, "Pages") do
      nil ->
        # If the root is already a /Pages node, use it directly as the tree root
        case Map.get(catalog, "Type") do
          {:name, "Pages"} -> {:ok, root_ref}
          _ -> {:error, :no_pages}
        end

      ref ->
        {:ok, ref}
    end
  end

  defp fetch_pages_ref_or_self(_root_ref, _), do: {:error, :no_pages}

  # ---------------------------------------------------------------------------
  # Internal — R-4 catalog/pages fallback
  # ---------------------------------------------------------------------------

  # Scan xref entries for /Type /Page objects that also carry /Contents or /Parent.
  # This filters out Form XObjects which may appear to have /Type /Page in some
  # malformed PDFs, or stream dicts with /Type /XObject /Subtype /Form which
  # definitely do NOT have /Parent or /Contents.
  defp recover_pages(doc, _reason) do
    page_refs = scan_xref_for_pages(doc)
    doc1 = Document.log_recovery(doc, {:page_tree_recovered, length(page_refs)})
    {:ok, page_refs, doc1}
  end

  defp scan_xref_for_pages(%Document{xref: xref} = doc) do
    xref
    |> Enum.flat_map(fn
      {{n, g}, {:in_use, _, _}} when is_integer(n) and is_integer(g) and n > 0 ->
        ref = {:ref, n, g}

        case ObjectResolver.resolve(doc, ref) do
          {:ok, dict, _} when is_map(dict) ->
            if page_dict?(dict), do: [{n, g}], else: []

          _ ->
            []
        end

      _ ->
        []
    end)
    |> Enum.sort()
  end

  # A dict qualifies as a recoverable page if:
  # 1. It has /Type /Page
  # 2. It has either /Contents or /Parent (to exclude Form XObjects and bare stream dicts)
  defp page_dict?(dict) do
    has_page_type =
      case Map.get(dict, "Type") do
        {:name, "Page"} -> true
        _ -> false
      end

    has_page_type and (Map.has_key?(dict, "Contents") or Map.has_key?(dict, "Parent"))
  end

  # ---------------------------------------------------------------------------
  # Internal — strict tree traversal (used from both strict_list_refs and
  # lenient walk_pages_node in recovery mode)
  # ---------------------------------------------------------------------------

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

  # Walk a /Pages intermediate node: iterate Kids, collect leaf refs.
  #
  # In strict mode (recover_mode false): uses Enum.reduce_while — first error halts.
  # In lenient mode (recover_mode true): uses Enum.reduce — bad kids are logged and
  # skipped, good kids accumulate. Appends {:page_failed, ref, reason} to recovery_log.
  defp walk_pages_node(%Document{recover_mode: true} = doc, %{"Kids" => kids})
       when is_list(kids) do
    {refs, final_doc} =
      Enum.reduce(kids, {[], doc}, fn kid_ref, {acc_refs, acc_doc} ->
        case walk_kids(acc_doc, kid_ref) do
          {:ok, new_refs, updated_doc} ->
            {acc_refs ++ new_refs, updated_doc}

          {:error, reason} ->
            # Log the bad kid and continue — do NOT halt
            kid_key = extract_kid_key(kid_ref)
            updated_doc = Document.log_recovery(acc_doc, {:page_failed, kid_key, reason})
            {acc_refs, updated_doc}
        end
      end)

    {:ok, refs, final_doc}
  end

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

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  # Extract the {n, g} key from a ref tuple
  defp ref_key({:ref, n, g}), do: {n, g}
  defp ref_key({n, g}), do: {n, g}

  # Extract a display key from a kid ref for the recovery log
  defp extract_kid_key({:ref, n, g}), do: {n, g}
  defp extract_kid_key(other), do: other
end
